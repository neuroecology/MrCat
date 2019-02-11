#!/usr/bin/env bash
set -e    # stop immediately on error
umask u+rw,g+rw # give group read/write permissions to all new files

# clean your functional data timeseries using regression of noise components

# TODO: make the matlab command nice, with try-catch and error messages
# TODO: set the nCompSignal dependent on nComp even if this is auto
# TODO: limit number of noise components to a maximal number if set to auto (code snippet already exist in comments below)


# ------------------------------ #
# Help
# ------------------------------ #

usage() {
cat <<EOF

rsn_cleanComp.sh: Clean functional data by regressing out noise components (WM/CSF)

example:
      sh rsn_cleanComp.sh --funcimg=func --funcout=func_out

usage: $(basename $0)
      obligatory arguments
        [--funcimg=<image>] : functional time series
        [--funcout=<image>] : output functional time series after regression
      optional arguments
        [--funcbase=<string>] : basename of the functional image
        [--structimg=<image>] : structural T1w image
        [--structbase=<string>] : basename of the structural image
        [--transdir=<directory>] : transformation directory
        [--decomp=<mean/eig/pca/ica>] : extract components, either the mean,
            eigen variate(s) (using fslmeants), principal components (using svd
            in matlab), or independent components (using melodic). default: pca
        [--ncomp=<integer>] : number of (noise) components. Defaults:
            mean: 1, eig: 1, pca: 3, ica: 12
        [--masknoise=<mask name>] : extract (noise) components form within the
            specified mask only. Common masks area WM and CSF, or versions
            thereof, such as the high-probability core of the mask only (e.g.
            'WMcore') or an eroded version (e.g. 'WMero'). To extract components
            from multiple masks separately, specify the mask in a
            comma-separated list (e.g. 'WMcore,CSFcore'). To extract components
            from multiple masks combined, specify the masks in a
            underscore-separated list (e.g. 'WMcore_CSFcore').
        [--masksignal=<mask name>] : If you want to keep variance shared between
            the noise components and good signal, you can specify a second mask
            from where to decompose the signal. The resulting components will be
            matched against those of the noise mask, and all those marked
            similar will be removed, but variance from all others will be kept.
            This is called 'soft' regression, as opposed to 'aggressive'
            regression. Generally, you might want to specify WM_CSF as the noise
            mask, and GM as the signal mask. This option ('--masksignal=GM') is
            default for ica decomposition (melodic). It has not been tested for
            other decomposition types.
        [--ncompsignal=<integer>] : number of signal components.
            Default: 2 x value at --ncomp
        [--motion=<path>] : path to file holding motion parameters
        [--motiondegree=<integer>] : degree of faux Volterra series to expand
            the motion parameters [canonical exponent derivative]
            Default: 1 (the 6 canonical parameters)

EOF
}

# ------------------------------ #
# Housekeeping
# ------------------------------ #
# if no arguments given, or help is requested, return the usage
if [[ $# -eq 0 ]] || [[ $@ =~ --help ]] ; then usage; exit 0; fi

# if too few arguments given, return the usage, exit with error
if [[ $# -lt 2 ]] ; then >&2 usage; exit 1; fi

# by default no signal mask is considered
maskSignal=""

# parse the input arguments
for a in "$@" ; do
  case $a in
    --funcimg=*)    funcImg="${a#*=}"; shift ;;
    --funcout=*)    funcOut="${a#*=}"; shift ;;
    --funcbase=*)   funcBase="${a#*=}"; shift ;;
    --structimg=*)  structImg="${a#*=}"; shift ;;
    --structbase=*) structBase="${a#*=}"; shift ;;
    --transdir=*)   transDir="${a#*=}"; shift ;;
    --decomp=*)     decompType="${a#*=}"; shift ;;
    --ncomp=*)      nComp="${a#*=}"; shift ;;
    --masknoise=*)  maskNoise="${a#*=}"; shift ;;
    --masksignal=*) maskSignal="${a#*=}"; shift ;;
    --ncompsignal=*) nCompSignal="${a#*=}"; shift ;;
    --motion=*)     motionConfounds="${a#*=}"; shift ;;
    --motiondegree=*) motionDegree="${a#*=}"; shift ;;
    *)              arg="$arg $a"; shift ;; # ordered arguments
  esac
done

# check if obligatory arguments have been set
if [[ -z $funcImg ]] ; then
  >&2 echo ""; >&2 echo "error: please specify the input image."
  usage; exit 1
fi
if [[ -z $funcOut ]] ; then
  >&2 echo ""; >&2 echo "error: please specify the output image."
  usage; exit 1
fi

# check if no redundant arguments have been set
if [[ -n $arg ]] ; then
  >&2 echo ""; >&2 echo "unsupported arguments are given:" $arg
  usage; exit 1
fi

# infer or set the functional directory and image
funcImg=$(remove_ext $funcImg)
funcOut=$(remove_ext $funcOut)
funcDir=$(dirname $funcImg)
[[ -z $funcBase ]] && funcBase=$(basename $funcImg)

# infer or set the structural directory and image
[[ -z $structImg ]] && structDir=$(cd $funcDir/../structural; pwd) && structImg=$structDir/struct
structImg=$(remove_ext $structImg)
structDir=$(dirname $structImg)
[[ -z $structBase ]] && structBase=$(basename $structImg)

# infer or set the tranformation directory
[[ -z $transDir ]] && transDir=$(cd $funcDir/../transform; pwd)

# set default decomposition specifications
[[ -z $decompType ]] && decompType='pca'
if [[ -z $nComp ]] ; then
  case $decompType in
    mean ) nComp=1 ;;
    eig ) nComp=1 ;;
    pca ) nComp=3 ;;
    ica ) nComp=12 ;;
  esac
fi
if [[ -z $maskNoise ]] ; then
  case $decompType in
    ica ) maskNoise="WMcore_CSFcore" ;;
    * ) maskNoise="WMcore,CSFcore" ;;
  esac
fi
if [[ $decompType == "ica" ]] ; then
  [[ -z $maskSignal ]] && maskSignal="GM"
  [[ -z $nCompSignal ]] && nCompSignal=$(echo $nComp 2 24 | awk '{n=$1*$2;if(n<$3)n=$3;print n}')
fi

# collect the requested masks in a list
maskBaseList=$(echo $maskNoise,$maskSignal | tr '_' ',' | tr ',' '\n' | sort | uniq)
maskCombList=$(echo $maskNoise,$maskSignal | tr ',' '\n' | grep '_' | sort | uniq)

# set the defaults for the motion parameters
[[ -z $motionConfounds ]] && motionConfounds=""
[[ -z $motionDegree ]] && motionDegree=1

# initialise an empty matlab command string (only used for --decomp=pca)
cmdMatlab=""


# ------------------------------ #
# Do the work
# ------------------------------ #

#=========================================
# ensure noise (WM/CSF) masks exist in structural space
#=========================================

# test if the T1w image needs to be segmented
flgSegment=0
for maskName in $maskBaseList ; do
  # if the mask does not exist
  if [[ ! -r $structDir/$maskName.nii.gz ]] ; then
    # test if the main (original) mask exists
    maskName=${maskName%%core*}; maskName=${maskName%%ero*}
    [[ ! -r $structDir/$maskName.nii.gz ]] && flgSegment=1
  fi
done

# segment the structural to obtain the masks
if [[ $flgSegment -eq 1 ]] ; then

  echo "segmenting the structural to obtain GM, WM, and CSF masks"
  echo "  results will probably be poor, use struct_macaque.sh --segment for"
  echo "  better segmentation quality"

  # initialise a temporary working directory
  workdir=$(mktemp -d "$structDir/tmp_segment.XXXXXXXXXX")
  mkdir -p $workdir
  imcp ${structImg}_restore_brain $workdir/struct_brain

  # segment the T1, without extra biascorrection
  fast -n 3 -t 1 -g --nobias $workdir/struct_brain
  if [[ ! -r $structDir/CSF.nii.gz ]] ; then
    immv $workdir/struct_brain_seg_0 $structDir/CSF
  fi
  if [[ ! -r $structDir/GM.nii.gz ]] ; then
    immv $workdir/struct_brain_seg_1 $structDir/GM
  fi
  if [[ ! -r $structDir/WM.nii.gz ]] ; then
    immv $workdir/struct_brain_seg_2 $structDir/WM
  fi

  # remove workdir
  rm -rf $workdir
fi

# test if the requested masks exist in structural space
for maskName in $maskBaseList ; do
  # if the mask does not exist
  if [[ ! -r $structDir/$maskName.nii.gz ]] ; then
    # handle eroded masks
    if [[ $maskName =~ ero$ ]] ; then
      echo "eroding ${maskName%%ero*} mask in structural space"
      case ${maskName%%ero*} in
        WM ) fslmaths $structDir/WM -ero -ero $structDir/WMero ;;
        CSF ) fslmaths ${structImg}_brain_mask -binv -add $structDir/CSF -ero -mas ${structImg}_brain_mask $structDir/CSFero ;;
        * ) fslmaths $structDir/${maskName%%ero*} -ero $structDir/$maskName ;;
      esac
    fi
    # handle core masks
    if [[ $maskName =~ core$ ]] ; then
      echo "$maskName mask not found in structural space"
      echo "  consider re-running struct_macaque.sh"
      echo "  now continuing with a poor substitute for $maskName mask"
      fslmaths $structDir/${maskName%%core*} -ero $structDir/$maskName
    fi
  fi
done


#=========================================
# resample structural masks in functional space
#=========================================

echo "resampling structural masks to functional space"
for maskName in $maskBaseList ; do
  applywarp --interp=nn -i $structDir/$maskName -r $funcDir/${funcBase}_brain_mask --premat=$transDir/${structBase}_to_${funcBase}.mat -o $funcDir/$maskName
done

# combine masks as requested
for maskCombName in $maskCombList ; do
  fullFillNameList=$(echo $maskCombName | tr '_' '\n' | awk '{print "'$funcDir/'" $1}' | tr '\n' ' ')
  fsladd $funcDir/$maskCombName $fullFillNameList > /dev/null
done


#=========================================
# Extract nuisance components
#=========================================

# extract components using ica (melodic), pca (matlab), or mean/eig (fslmeants)
flgCombineComb=1
if [[ $decompType == "ica" ]] ; then

  # initialise a config and a main melodic directory
  echo "preparing for MELODIC"
  melodicConfigDir=$funcDir/melodic.config
  melodicSignalDir=$funcDir/melodic_signal.ica
  melodicNoiseDir=$funcDir/melodic_noise.ica
  rm -rf $melodicConfigDir $melodicSignalDir $melodicNoiseDir
  mkdir -p $melodicConfigDir

  # retrieve the TR and number of volumes from the data
  pixdim4=$(fslval $funcImg "pixdim4")
  accelFactor=2
  TR=$(echo $pixdim4 $accelFactor | awk '{print $1/$2}')
  nVols=$(fslnvols $funcImg)

  # prepare and run MELODIC for the noise compartment
  #----------
  echo "extracting mean noise timeseries"
  compNoiseAggressive=${funcImg}_${maskNoise}_mean.txt
  fslmeants -i $funcImg -m $funcDir/$maskNoise -o $compNoiseAggressive

  echo "running MELODIC on the noise compartment"
  # extract the functional data in the noise compartment
  fslmaths $funcImg -add 1000 -mas $funcDir/$maskNoise $melodicConfigDir/dataNoise

  # copy the melodic configuration template
  cp $MRCATDIR/pipelines/rfmri_macaque/melodic_config.fsf $melodicConfigDir/configNoise.fsf

  # set-up the MELODIC configuration: output directory, input file, explicit mask, number of volumes, TR, number of components
  sed -i '' 's@set fmri(outputdir).*@set fmri(outputdir) "'$melodicNoiseDir'"@' $melodicConfigDir/configNoise.fsf
  sed -i '' 's@set feat_files(1).*@set feat_files(1) "'$melodicConfigDir/dataNoise'"@' $melodicConfigDir/configNoise.fsf
  sed -i '' 's@set fmri(alternative_mask).*@set fmri(alternative_mask) "'$funcDir/$maskNoise'"@' $melodicConfigDir/configNoise.fsf
  sed -i '' 's@set fmri(npts).*@set fmri(npts) '$nVols'@' $melodicConfigDir/configNoise.fsf
  sed -i '' 's@set fmri(tr).*@set fmri(tr) '$TR'@' $melodicConfigDir/configNoise.fsf

  if [[ $nComp == "auto" ]] ; then
    sed -i '' 's@set fmri(dim_yn).*@set fmri(dim_yn) 1@' $melodicConfigDir/configNoise.fsf
    sed -i '' 's@set fmri(dim).*@set fmri(dim) 1@' $melodicConfigDir/configNoise.fsf
  else
    sed -i '' 's@set fmri(dim_yn).*@set fmri(dim_yn) 0@' $melodicConfigDir/configNoise.fsf
    sed -i '' 's@set fmri(dim).*@set fmri(dim) '$nComp'@' $melodicConfigDir/configNoise.fsf
  fi

  # run MELODIC on the noise compartment
  flgRun=1
  while [[ $flgRun -eq 1 ]] ; do

    # this is finally where melodic is called
    feat $melodicConfigDir/configNoise.fsf

    # if MELODIC fails... re-run with more components
    if [[ ! -s $melodicNoiseDir/filtered_func_data.ica/melodic_mix ]] ; then
      echo "MELODIC failed to converge, re-running with more components"
      rm -rf $melodicNoiseDir
      nComp=$((nComp+2))
      sed -i '' 's@set fmri(dim).*@set fmri(dim) '$nComp'@' $melodicConfigDir/configNoise.fsf
    else
      flgRun=0
    fi

  done

  # copy MELODIC noise components to functional directory
  compNoise=${funcImg}_${maskNoise}_melodic.txt
  cp $melodicNoiseDir/filtered_func_data.ica/melodic_mix $compNoise

  # example code to limit the number of components
  #compNoiseFull=${funcImg}_${maskNoise}_melodic_full.txt
  #[[ ! -r $compNoiseFull ]] && cp $compNoise $compNoiseFull
  #sed "s@  @ @g" $compNoiseFull | cut -d ' ' -f -$nComp > $compNoise

  # if requested, prepare and run MELODIC for the signal compartment
  #----------
  compSignal=""
  if [[ -n $maskSignal ]] ; then
    echo "running MELODIC on signal compartment"

    # extract the functional data in the noise compartment
    fslmaths $funcImg -add 1000 -mas $funcDir/$maskSignal $melodicConfigDir/dataSignal

    # copy the melodic configuration template
    cp $MRCATDIR/pipelines/rfmri_macaque/melodic_config.fsf $melodicConfigDir/configSignal.fsf\

    # set-up the MELODIC configuration: output directory, input file, explicit mask, number of volumes, TR,
    sed -i '' 's@set fmri(outputdir).*@set fmri(outputdir) "'$melodicSignalDir'"@' $melodicConfigDir/configSignal.fsf
    sed -i '' 's@set feat_files(1).*@set feat_files(1) "'$melodicConfigDir/dataSignal'"@' $melodicConfigDir/configSignal.fsf
    sed -i '' 's@set fmri(alternative_mask).*@set fmri(alternative_mask) "'$funcDir/$maskSignal'"@' $melodicConfigDir/configSignal.fsf
    sed -i '' 's@set fmri(npts).*@set fmri(npts) '$nVols'@' $melodicConfigDir/configSignal.fsf
    sed -i '' 's@set fmri(tr).*@set fmri(tr) '$TR'@' $melodicConfigDir/configSignal.fsf
    # set number of components for the signal compartment, either automatically or fixed
    if [[ $nCompSignal == "auto" ]] ; then
      sed -i '' 's@set fmri(dim_yn).*@set fmri(dim_yn) 1@' $melodicConfigDir/configSignal.fsf
      sed -i '' 's@set fmri(dim).*@set fmri(dim) 1@' $melodicConfigDir/configSignal.fsf
    else
      # set a fixed number of components for the signal compartment (maximally nVols-1, recommended: 2 x nComp)
      nCompSignal=$(echo $nCompSignal $((nVols-1)) | awk '{n=$1;if(n>$2)n=$2;print n}')
      sed -i '' 's@set fmri(dim_yn).*@set fmri(dim_yn) 0@' $melodicConfigDir/configSignal.fsf
      sed -i '' 's@set fmri(dim).*@set fmri(dim) '$nCompSignal'@' $melodicConfigDir/configSignal.fsf
    fi

    # run MELODIC on the signal compartment
    flgRun=1
    while [[ $flgRun -eq 1 ]] ; do

      # this is finally where melodic is called
      feat $melodicConfigDir/configSignal.fsf

      # if MELODIC fails... re-run with more components
      if [[ ! -s $melodicSignalDir/filtered_func_data.ica/melodic_mix ]] ; then
        echo "MELODIC failed to converge, re-running with more components"
        rm -rf $melodicSignalDir
        nCompSignal=$((nCompSignal+4))
        sed -i '' 's@set fmri(dim).*@set fmri(dim) '$nCompSignal'@' $melodicConfigDir/configSignal.fsf
      else
        flgRun=0
      fi

    done

    # copy MELODIC signal components to functional directory
    compSignal=${funcImg}_${maskSignal}_melodic.txt
    cp $melodicSignalDir/filtered_func_data.ica/melodic_mix $compSignal

  else

    # if no signal compartment is specified, combine the mean with the components
    compNoise="$compNoiseAggressive $compNoise"

  fi

  # clean-up melodic directories
  rm -rf $melodicConfigDir $melodicSignalDir $melodicNoiseDir


elif [[ $decompType == "mean" ]] ; then

  # check if input is compatible with extracting the mean
  if [[ $nComp -gt 1 ]] ; then >&2 printf "\n  ERROR: you specified to extract the mean noise timeseries,\n  but requested more than 1 component (--ncomp=%d).\n\n" $nComp; exit 1; fi
  if [[ -n $maskSignal ]] ; then >&2 printf "\n  ERROR: the mean noise and signal timeseries are not appropriate when aiming to keep the \"good\" signal intact\n  --masksignal=%s\n  Please drop the --masksignal or use principal or independent component analyses.\n\n" $maskSignal; exit 1; fi

  # loop over the noise compartments
  echo "extracting mean time-course"
  compNoise=""
  for maskName in ${maskNoise//,/ } ; do
    echo "  $maskName"
    fslmeants -i ${funcImg} -o ${funcImg}_${maskName}_mean.txt  -m $funcDir/$maskName.nii.gz
    compNoise+="${funcImg}_${maskName}_mean.txt "
  done

elif [[ $decompType == "eig" ]] ; then

  # loop over the noise compartments
  echo "extracting eigen variates"
  compNoise=""
  for maskName in ${maskNoise//,/ } ; do
    echo "  $maskName"
    fslmeants -i ${funcImg} -o ${funcImg}_${maskName}_eig.txt  -m $funcDir/$maskName.nii.gz --eig --order=$nComp
    compNoise+="${funcImg}_${maskName}_eig.txt "
  done

  # loop over the signal compartments
  compSignal=""
  if [[ -n $maskSignal ]] ; then
    for maskName in ${maskSignal//,/ } ; do
      echo "  $maskName"
      fslmeants -i ${funcImg} -o ${funcImg}_${maskName}_eig.txt  -m $funcDir/$maskName.nii.gz --eig --order=$nCompSignal
      compSignal+="${funcImg}_${maskName}_eig.txt "
    done
  fi


else

  # principal component analysis (matlab)
  printf "extracting and "
  flgCombineComb=0

  # perpare a matlab command to run all decompositions and regressions in one go
  cmdMatlab=""
  # loop over the noise compartments
  compNoise=""
  for maskName in ${maskNoise//,/ } ; do
    cmdMatlab+="rsn_decomp({'$funcImg.nii.gz','$funcDir/$maskName.nii.gz'},$nComp,'pca','${funcImg}_${maskName}');"
    [[ -n $compNoise ]] && compNoise+=","
    compNoise+="'${funcImg}_${maskName}_comp.txt'"
  done

  # loop over the signal compartments
  compSignal=""
  if [[ -n $maskSignal ]] ; then
    for maskName in ${maskSignal//,/ } ; do
      cmdMatlab+="rsn_decomp({'$funcImg.nii.gz','$funcDir/$maskName.nii.gz'},$nCompSignal,'pca','${funcImg}_${maskName}');"
      [[ -n $compSignal ]] && compSignal+=","
      compSignal+="'${funcImg}_${maskName}_comp.txt'"
    done
  fi

fi


#=========================================
# Regress out nuisance components
#=========================================

# set compNoiseAggressive to an empty string if not used
[[ -z $compNoiseAggressive ]] && compNoiseAggressive=""

# combine lists of components
if [[ $flgCombineComb -eq 1 ]] ; then
  # prepare component lists for matlab processing
  paste $compNoise > ${funcImg}_compNoise.txt
  compNoise=${funcImg}_compNoise.txt
  if [[ -n $compSignal ]] ; then
    paste $compSignal > ${funcImg}_compSignal.txt
    compSignal=${funcImg}_compSignal.txt
  fi
  compNoise="'$compNoise'"
  compSignal="'$compSignal'"
fi

# perpare motion parameters, if requested
if [[ -n $motionConfounds ]] ; then
  motionConfoundsExpanded=${funcImg}_motionConfounds.txt
  cmdMatlab+="ExpandMotionConfounds('$motionConfounds','$motionConfoundsExpanded',$motionDegree);"
  if [[ -n $maskSignal ]] ; then
    if [[ -z $compNoiseAggressive ]] ; then
      compNoiseAggressive="'$motionConfoundsExpanded'"
    else
      compNoiseAggressive="{'$compNoiseAggressive','$motionConfoundsExpanded'}"
    fi
  else
    compNoise="{$compNoise,'$motionConfoundsExpanded'}"
  fi
else
  compNoiseAggressive="'$compNoiseAggressive'"
fi

# ensure the compSignal is stored between curly brackets
[[ -n $compSignal ]] && [[ ! $compSignal =~ ^{ ]] && compSignal="{$compSignal}"

# switch between different regression types
if [[ -n $maskSignal ]] ; then
  echo "regressing out noise components, while keeping good signal"

  # a signal mask is provided, requesting to keep the good components
  $MATLABBIN/matlab -nodisplay -nosplash -r "addpath('$MRCATDIR');setupMrCat;${cmdMatlab};rsn_cleanComp('${funcImg}.nii.gz',$compSignal,$compNoise,$compNoiseAggressive,'${funcOut}.nii.gz');exit"

else
  echo "regressing out noise components"

  # no signal mask is provided, the noise components are simply regressed out
  $MATLABBIN/matlab -nodisplay -nosplash -r "addpath('$MRCATDIR');setupMrCat;${cmdMatlab};rsn_cleanCompSimple('${funcImg}.nii.gz',$compNoise,'${funcOut}.nii.gz');exit"

fi


echo "  done"
