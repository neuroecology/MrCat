#!/usr/bin/env bash
set -e    # stop immediately on error

# preprocessing of a macaque structural image
# 1. brain extraction
# 2. bias correction
# 3. reference registration
# these steps are dependent on each other and could therefore be repeated for
# the best results

# TODO: calculate the flirt cost based on the brain extracted image

# ------------------------------ #
# usage
# ------------------------------ #

usage() {
cat <<EOF

Preprocess macaque structural MRI. Brain extraction, bias correction, and
  reference registration.

example:
  struct_macaque.sh --subjdir=MAC1 --all
  struct_macaque.sh --subjdir=MAC1 --once
  struct_macaque.sh --subjdir=MAC1 --structImg=struct/struct --betorig --biascorr

usage: struct_macaque.sh
  instructions:
    [--all] : execute all inctructions, twice: --robustfov --betorig --biascorr
      --betrestore --register --brainmask --biascorr --register --brainmask
      --segment
    [--once] : execute all instructions once: --robustfov --betorig --biascorr
      --betrestore --register --brainmask --segment
    [--robustfov] : robust field-of-view cropping
    [--betorig] : rough brain extraction of the original structural
    [--betrestore] : brain extraction of the restored structural
    [--biascorr] : correct the spatial bias in signal intensity
    [--register] : register to the reference and warp the refMask back
    [--brainmask] : retrieve the brain mask from the reference and polish
    [--segment] : segment the structural image in CSF, GM, and WM compartments
    [--hemimask] : create masks for each hemisphere (left/right)
  settings:
    [--subjdir=<subject dir>] default: <current directory>
    [--structdir=<structural dir>] default: <subjdir>/struct
    [--structimg=<structural image>] default: <structdir>/struct
      the <structdir> can be inferred from <structImg>, if provided
    [--structmask=<structural brain mask>] default: <structimg>_brain_mask
    [--transdir=<transform dir>] default: <subjdir>/transform
    [--scriptdir=<script dir>] default: <parent directory of struct_macaque.sh>
      path to bet_macaque.sh and robustfov_macaque.sh scripts
    [--refdir=<reference dir>] default: <inferred from refimg, or scriptdir>
      path to reference images
    [--fovmm=<XSIZExYSIZExZSIZE> default: 128x128x64
      field-of-view in mm, for robustfov_macaque
    [--config=<fnirt config file> default: <scriptdir>/fnirt_1mm.cnf
    [--refspace=<reference space name>] default: F99, alternative: SL, MNI
    [--refimg=<ref template image>] default: <scriptdir>/<refspace>/McLaren
    [--refmask=<reference brain mask>] default: <refimg>_brain_mask
    [--refweightflirt=<ref weights for flirt>] default <refmask>
    [--refmaskfnirt=<ref brain mask for fnirt>] default <refmask>
    [--flirtoptions]=<extra options for flirt>] default none

EOF
}


# ------------------------------ #
# process and test the input arguments
# ------------------------------ #

# if no arguments given, or help is requested, return the usage
[[ $# -eq 0 ]] || [[ $@ =~ --help ]] && usage && exit 0

# if not given, retrieve directory of this script
[[ $0 == */* ]] && thisscript=$0 || thisscript="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/$0

# if "--all" is given, run the default set
if [[ $@ =~ --all$ ]] || [[ $@ =~ "--all " ]] ; then
  # the default arguments associated with "--all" / "--nonlin"
  defaultset="--robustfov --betorig --biascorr --betrestore --register --brainmask --biascorr --register --brainmask --hemimask --segment"
  echo "running the complete set of instructions: $defaultset"
  # replace "--all" with the default argument set
  newargs=$(echo "${@//--all/$defaultset}")
  # execute this script with the default argument set, and passing others
  sh $thisscript $newargs
  exit 0
elif [[ $@ =~ --once$ ]] || [[ $@ =~ "--once " ]] ; then
  # the default arguments associated with "--all" / "--nonlin"
  defaultset="--robustfov --betorig --biascorr --betrestore --register --brainmask --hemimask --segment"
  echo "running the complete set of instructions: $defaultset"
  # replace "--once" with the default argument set
  newargs=$(echo "${@//--once/$defaultset}")
  # execute this script with the default argument set, and passing others
  sh $thisscript $newargs
  exit 0
fi

# run each instruction on its own (with the same definitions)
definitionargs=$(echo "$@" | tr " " "\n" | grep '=') || true
instructargs=$(echo "$@" | tr " " "\n" | grep -v '=') || true
if [[ $(echo "$instructargs" | wc -w) -gt 1 ]] ; then
  # this ensures the instructions are executed as specified, not as coded
  for instr in $instructargs ; do
    sh $thisscript $definitionargs $instr
  done
  exit 0
fi

# count and grep the number of argument repetitions (ignoring after "=")
duplicates=$(echo "$@" | tr " " "\n" | awk '{ gsub("=.*","="); print $0}' | sort | uniq -c | grep -v '^ *1 ') || true   # "|| true" is added to ignore the non-zero exit code of grep (and avoid the script the stop because of "set -e")
# now test if any duplicates were found, and if so, give an error
[[ -n $duplicates ]] && >&2 echo "\nError, repetitions found in the arguments:\n$@\n${duplicates}\n" && exit 1


# ------------------------------ #
# arguments and defaults
# ------------------------------ #
# set defaults
instr=""
subjDir="."
structImg="struct"
structMask=""
[[ -n $MRCATDIR ]] && scriptDir=$MRCATDIR/core &&
echo "Script directory: $scriptDir"
hcpDir="" # legacy, will give warning when set and will be ignored
refDir=$MRCATDIR/data/macaque
transDir="transform"
fovmm="128 128 64"
config="fnirt_1mm.cnf"
refSpace="F99"
refImg="McLaren"
flirtoptions=""

# parse the input arguments
for a in "$@" ; do
  case $a in
    --subjdir=*)        subjDir="${a#*=}"; shift ;;
    --structdir=*)      structDir="${a#*=}"; shift ;;
    --structimg=*)      structImg="${a#*=}"; shift ;;
    --structmask=*)     structMask="${a#*=}"; shift ;;
    --transdir=*)       transDir="${a#*=}"; shift ;;
    --scriptdir=*)      scriptDir="${a#*=}"; shift ;;
    --hcpdir=*)         hcpDir="${a#*=}"; shift ;; # legacy, will give warning and will be ignored
    --refdir=*)         refDir="${a#*=}"; shift ;;
    --fovmm=*)          fovmm="${a#*=}"; shift ;;
    --config=*)         config="${a#*=}"; shift ;;
    --refspace=*)       refSpace="${a#*=}"; shift ;;
    --refimg=*)         refImg="${a#*=}"; shift ;;
    --refmask=*)        refMask="${a#*=}"; shift ;;
    --refweightflirt=*) refweightflirt="${a#*=}"; shift ;;
    --refmaskfnirt=*)   refMaskfnirt="${a#*=}"; shift ;;
    --flirtoptions=*)   flirtoptions="${a#*=}"; shift ;;
    *)                  instr="$instr $a"; shift ;; # instruction argument
  esac
done

# split the fovmm argument, if given
fovmm=$(echo $fovmm | tr "x" " ")

# input dependent defaults
[[ -z $structDir ]] && structDir="${structImg%/*}"
[[ -d $structDir ]] && structDir="$(cd "$structDir" && pwd)"
[[ -z $structDir ]] && structDir="struct"
structImg=${structImg##*/}    # remove the directory
structImg=${structImg%%.*}    # remove the extension
structImg=${structImg%%_brain*} # remove "_brain" postpad
structImg=${structImg%%_restore*} # remove "_restore" postpad
structMask=${structMask%%.*}  # remove the extension
spaceDir="$refSpace"
refImg=${refImg%%.*}  # remove the extension
[[ -z $refMask ]] && refMask="${refImg}_brain_mask"
refMask=${refMask%%.*}  # remove the extension
#baserefImg=${refImg##*/}    # remove the directory
#if [[ ${baserefImg%%.*} == "McLaren" ]] ; then
#  [[ -z $refweightflirt ]] && refweightflirt="$refImg"
#  [[ -z $refMaskfnirt ]] && refMaskfnirt="${refMask}_strict"
#fi

# sort the location of the different script directories
[[ -z $refweightflirt ]] && refweightflirt="$refMask"
[[ -z $refMaskfnirt ]] && refMaskfnirt="$refMask"
[[ -z $scriptDir ]] && scriptDir="$(cd "$(dirname ${BASH_SOURCE[0]})"/.. && pwd)"
[[ -n $hcpDir ]] && printf '\n\nWarning: The input argument --hcpdir is no longer valid and will be ignored.\n\n' # legacy, will give warning and will be ignored
[[ -z $refDir ]] && refDir=$(cd $MRCATDIR/data/macaque && pwd)
[[ ! -d $refDir ]] && refDir=$scriptDir

# prepad the directory if none is given
[[ $config != */* ]] && config=$MRCATDIR/config/$config
[[ $structDir != */* ]] && structDir=$subjDir/$structDir
[[ $spaceDir != */* ]] && spaceDir=$subjDir/$spaceDir
[[ $transDir != */* ]] && transDir=$subjDir/$transDir
[[ $refImg != */* ]] && refImg=$refDir/$refSpace/$refImg
[[ $refMask != */* ]] && refMask=$refDir/$refSpace/$refMask
[[ $refweightflirt != */* ]] && refweightflirt=$refDir/$refSpace/$refweightflirt
[[ $refMaskfnirt != */* ]] && refMaskfnirt=$refDir/$refSpace/$refMaskfnirt


# ------------------------------ #
# the instructions are coded below
# ------------------------------ #

# first rough brain extraction
if [[ $instr =~ --robustfov$ ]] ; then
  # input:  original structImg
  # output: (cropped) structImg with robust field-of-view

  # call robustfov_macaque.sh to ensure a robust field-of-view
  $scriptDir/robustfov_macaque.sh $structDir/$structImg -m $fovmm -f

fi


# first rough brain extraction
if [[ $instr =~ --betorig$ ]] || [[ $instr =~ --betrestore$ ]] ; then
  # input:  original or restored structImg
  # output: {structImg}_brain_mask

  # definitions
  if [[ $instr =~ --betorig$ ]] ; then
    img=$structDir/$structImg
    fbrain=0.2
    niter=3
  else
    img=$structDir/${structImg}_restore
    fbrain=0.25
    niter=10
  fi
  base=$structDir/$structImg
  [[ -z $structMask ]] && structMask=${base}_brain_mask

  # call bet_macaque.sh for an initial brain extraction
  $scriptDir/bet_macaque.sh $img $base --fbrain $fbrain --niter $niter

  # remove old brain extractions, and create new ones
  imrm ${base}_brain ${img}_brain
  [[ -r ${base}.nii.gz ]] && fslmaths $base -mas $structMask ${base}_brain
  [[ -r ${img}.nii.gz ]] && fslmaths $img -mas $structMask ${img}_brain

  # copy the brain mask for later inspection
  imcp $structMask ${structMask}_bet

fi


# bias correct the corrected image
if [[ $instr =~ --biascorr$ ]] ; then
  # input:  structImg
  # output: {structImg}_restore
  base=$structDir/${structImg}
  [[ -z $structMask ]] && structMask=${base}_brain_mask
  echo "bias correcting image: $base"

  # ignore dark voxels
  thr=$(fslstats ${base}_brain -P 5)
  cluster --in=${base}_brain --thresh=$thr --no_table --connectivity=6 --minextent=10000 --oindex=${structMask}_biascorr
  # and the super bright
  thr=$(fslstats ${base}_brain -P 99.8)
  fslmaths ${base}_brain -uthr $thr -mas ${structMask}_biascorr -bin ${structMask}_biascorr

  # smoothness definitions
  sigma=3
  FWHM=$(echo "2.3548 * $sigma" | bc)

  # run RobustBiasCorr
  $MRCATDIR/core/RobustBiasCorr.sh \
    --in=$base \
    --workingdir=$structDir/biascorr \
    --brainmask=${structMask}_biascorr \
    --basename=struct \
    --FWHM=$FWHM \
    --type=1 \
    --forcestrictbrainmask="FALSE" --ignorecsf="FALSE"

  # copy the restored image and bias field, and remove working directory
  imcp $structDir/biascorr/struct_restore ${base}_restore
  imcp $structDir/biascorr/struct_bias ${base}_bias
  rm -rf $structDir/biascorr

  # clean up
  imrm ${structMask}_biascorr

  echo "  done"

fi


# reference registration
if [[ $instr =~ --register$ ]] ; then
  base=$structDir/${structImg}
  [[ -z $structMask ]] && structMask=${base}_brain_mask
  echo "register ${base}_restore to reference: $refImg"

  # ensure the reference and transformation directories exist
  mkdir -p $spaceDir
  mkdir -p $transDir

  # perform linear registration of the structural to reference
  echo "  linear registration"
  flirt -dof 12 -ref $refImg -refweight $refweightflirt -in ${base}_restore -inweight $structMask -omat $transDir/${structImg}_to_${refSpace}.mat $flirtoptions

  # check cost of this registration
  cost=$(flirt -ref $refImg -in ${base}_restore -schedule $FSLDIR/etc/flirtsch/measurecost1.sch -init $transDir/${structImg}_to_${refSpace}.mat | head -1 | cut -d' ' -f1)

  # decide if flirt is good enough or needs another try
  if [[ $(echo $cost | awk '($1>0.9){print 1}') ]] ; then
    echo "  registration is poor: the cost is $cost"
    echo "  for reference, a value of 0.8 or lower would be nice"
    echo "  rerunning linear registration with restricted search"

    # see if the original flirt was run without search
    if [[ $flirtoptions =~ -nosearch ]] ; then
      # remove the -nosearch option, but use a restricted schedule (simple3D)
      flirt -dof 12 -ref $refImg -refweight $refweightflirt -in ${base}_restore -inweight $structMask -omat $transDir/${structImg}_to_${refSpace}_restricted.mat -schedule $FSLDIR/etc/flirtsch/simple3D.sch ${flirtoptions//-nosearch/}
    else
      # run flirt without search
      flirt -dof 12 -ref $refImg -refweight $refweightflirt -in ${base}_restore -inweight $structMask -omat $transDir/${structImg}_to_${refSpace}_restricted.mat -nosearch $flirtoptions
    fi

    # calculate cost of restricted registration
    costrestr=$(flirt -ref $refImg -in ${base}_restore -schedule $FSLDIR/etc/flirtsch/measurecost1.sch -init $transDir/${structImg}_to_${refSpace}_restricted.mat | head -1 | cut -d' ' -f1)

    # check if the new registration is actually better
    echo "  restricted registration cost is $costrestr"
    if [[ $(echo $cost $costrestr | awk '($1<$2){print 1}') ]] ; then
      # reject new registration
      echo "  keeping original registration, but please be warned of poor results"
      rm -rf $transDir/${structImg}_to_${refSpace}_restricted.mat
    else
      if [[ $(echo $costrestr | awk '($1>0.9){print 1}') ]] ; then
        echo "  continuing, but please be warned of poor registration results"
      else
        echo "  restricted registration is accepted"
      fi
      # use new registration
      mv -f $transDir/${structImg}_to_${refSpace}_restricted.mat $transDir/${structImg}_to_${refSpace}.mat
    fi

  else
    echo "  the linear registration cost is $cost"
  fi

  # invert linear transformation
  convert_xfm -omat $transDir/${refSpace}_to_${structImg}.mat -inverse $transDir/${structImg}_to_${refSpace}.mat

  # use spline interpolation to apply the linear transformation matrix
  applywarp --rel --interp=spline -i ${base}_restore -r $refImg --premat=$transDir/${structImg}_to_${refSpace}.mat -o $spaceDir/${structImg}_restore_lin
  fslmaths $spaceDir/${structImg}_restore_lin -thr 0 $spaceDir/${structImg}_restore_lin
  applywarp --rel --interp=nn -i $refMask -r $base --premat=$transDir/${refSpace}_to_${structImg}.mat -o ${structMask}_${refSpace}lin

  # now preform non-linear registration
  echo "  non-linear registration"
  #fnirt --ref=$refImg --refmask=$refMaskfnirt --in=${base}_restore --inmask=$structMask --aff=$transDir/${structImg}_to_${refSpace}.mat --fout=$transDir/${structImg}_to_${refSpace}_warp --config=$config
  fnirt --ref=$refImg --refmask=$refMaskfnirt --in=${base}_restore --aff=$transDir/${structImg}_to_${refSpace}.mat --fout=$transDir/${structImg}_to_${refSpace}_warp --config=$config

  # use spline interpolation to apply the warp field
  echo "  applying and inverting warp"
  applywarp --rel --interp=spline -i ${base}_restore -r $refImg -w $transDir/${structImg}_to_${refSpace}_warp -o $spaceDir/${structImg}_restore
  fslmaths $spaceDir/${structImg}_restore -thr 0 $spaceDir/${structImg}_restore

  # invert the warp field
  invwarp -w $transDir/${structImg}_to_${refSpace}_warp -o $transDir/${refSpace}_to_${structImg}_warp -r ${base}

  # and ditch the warp coeficient and log
  rm -f ${base}*warpcoef*
  mv -f ${base}*to_*.log $transDir/

  echo "  done"
fi


# retrieve and polish the brain mask
if [[ $instr =~ --brainmask$ ]] ; then
  # input:  {structImg}_restore, {structImg}_brain_mask
  # output: {structImg}_brain_mask
  base=$structDir/${structImg}
  [[ -z $structMask ]] && structMask=${base}_brain_mask
  echo "retrieve and polish the brain mask based on: $refImg"

  # warp the brain mask from reference to struct
  applywarp --rel --interp=nn -i $refMask -r $base -w $transDir/${refSpace}_to_${structImg}_warp -o $structMask
  imcp $structMask ${structMask}_$refSpace

  # smooth out the brain mask (and just ever so slightly dilate)
  fslmaths $structMask -s 1 -thr 0.45 -bin $structMask

  # extract the brain
  fslmaths ${base}_restore -mas $structMask ${base}_brain

  # remove old brain extractions, and create new ones
  imrm ${base}_brain ${base}_restore_brain
  [[ -r ${base}.nii.gz ]] && fslmaths $base -mas $structMask ${base}_brain
  [[ -r ${base}_restore.nii.gz ]] && fslmaths ${base}_restore -mas $structMask ${base}_restore_brain

  # and make a strict mask
  thr=$(fslstats ${base}_brain -P 5)
  cluster --in=${base}_brain --thresh=$thr --no_table --connectivity=6 --minextent=10000 --oindex=${structMask}_strict
  fslmaths ${structMask}_strict -bin -fillh -s 0.5 -thr 0.5 -bin -mas $structMask -fillh ${structMask}_strict

  echo "  done"

fi


# segment
if [[ $instr =~ --segment$ ]] ; then
  # input:  {structImg}_restore_brain OR {structImg}_restore, {structImg}_brain_mask
  # output: CSF GM GMcore GMall WM WMcore
  base=$structDir/${structImg}
  [[ -z $structMask ]] && structMask=${base}_brain_mask
  echo "segment the structural in CSF, GM, WM compartments"

  # pick the best image to work on
  flgBias="--nobias"
  workImg=${base}_restore_brain
  if [[ ! -r $workImg.nii.gz ]] ; then
    [[ -r ${base}_restore.nii.gz ]] && workImg=${base}_restore || (workImg=${base} && flgBias="")
    if [[ -r ${workImg}_brain.nii.gz ]] ; then
      workImg=${workImg}_brain
    elif [[ -r $structMask.nii.gz ]] ; then
      fslmaths $workImg -mas $structMask ${workImg}_brain
      workImg=${workImg}_brain
    else
      >&2 echo "please provide a brain extracted structural image, or provide a brain mask"
      exit 1
    fi
  fi

  # definitions
  workDir=$(mktemp -d "$structDir/tmp_segment.XXXXXXXXXX")
  mkdir -p $workDir
  structName=struct_brain

  # segment (but priors don't seem to help fast)
  echo "  running fast to segment the structural (ignoring priors)"
  fast --class=3 --type=1 --segments $flgBias -p --out=$workDir/$structName $workImg

  echo "  polishing compartments based on posterior probability"
  # identify segments
  median0=$(fslstats $workImg -k $workDir/${structName}_seg_0 -P 50)
  median1=$(fslstats $workImg -k $workDir/${structName}_seg_1 -P 50)
  median2=$(fslstats $workImg -k $workDir/${structName}_seg_2 -P 50)
  idx=$(echo $median0 $median1 $median2 | tr " " "\n" | nl -v0 | sort -nrk2 | awk '{print $1}')
  iWM=$(echo "$idx" | awk 'NR==1{print $1}')
  iGM=$(echo "$idx" | awk 'NR==2{print $1}')
  iCSF=$(echo "$idx" | awk 'NR==3{print $1}')

  # keep only the larger contiguous cluster as a WM mask
  cluster --in=$workDir/${structName}_pve_$iWM --thresh=1 --no_table --minextent=10000 --oindex=$workDir/WM

  # keep only the high probability CSF voxels and exclude any WM voxels
  if [[ -r ${structMask}_strict.nii.gz ]] ; then
    # anything outside the strict brain mask is CSF
    fslmaths ${structMask} -sub ${structMask}_strict -add $workDir/${structName}_pve_$iCSF -thr 1 -bin -sub $workDir/WM -bin $workDir/CSF
  else
    fslmaths $workDir/${structName}_pve_$iCSF -thr 1 -bin -sub $workDir/WM -bin $workDir/CSF
  fi

  # GMall is the inverse of CSF+WM, within the brain mask
  if [[ -r $structMask.nii.gz ]] ; then
    fslmaths $workDir/WM -add $workDir/CSF -binv -mas $structMask $workDir/GMall
  else
    fslmaths $workDir/WM -add $workDir/CSF -binv -mas $workDir/${structName}_seg $workDir/GMall
  fi

  # make a mask where we are more sure of the GM
  fslmaths $workDir/${structName}_pve_$iGM -s 1 -thr 0.5 -bin -mas $workDir/GMall $workDir/GM

  # Place for HACK

  # define priors for compartments and subcortical structures based on reference
  warp=$transDir/${refSpace}_to_${structImg}_warp
  refSubCortMask=$MRCATDIR/data/macaque/$refSpace/subcortMask
  refCSF=${refImg}_CSF
  refGM=${refImg}_GM
  refWM=${refImg}_WM

  # try to retrieve a subcortical atlas and assign those structures to GM and GMall, removing them from CSF and WM
  if [[ -r $refSubCortMask.nii.gz ]] && [[ -r $warp.nii.gz ]] ; then

    # warp subcortical atlas from reference space to structural space
    echo "  warping subcortical atlas from the reference template to the structural"
    if [[ -r ${structMask}.nii.gz ]] ; then
      applywarp --rel --interp=nn -i $refSubCortMask -r $workImg -m $structMask -w $warp -o $workDir/subcortMask
    else
      applywarp --rel --interp=nn -i $refSubCortMask -r $workImg -m $workDir/${structName}_seg -w $warp -o $workDir/subcortMask
    fi

    # add subcortical structures to the GM and GMall masks
    fslmaths $workDir/GM -add $workDir/subcortMask -bin $workDir/GM
    fslmaths $workDir/GMall -add $workDir/subcortMask -bin $workDir/GMall

    # exclude subcortical structures from the WM and CSF masks
    fslmaths $workDir/WM -bin -sub $workDir/subcortMask -bin $workDir/WM
    fslmaths $workDir/CSF -bin -sub $workDir/subcortMask -bin $workDir/CSF

  else

    echo "  missing subcortical atlas or warp field, continuing without"

  fi

  # try to use compartment priors from the reference image to define compartment cores
  if [[ -r $refCSF.nii.gz ]] && [[ -r $refGM.nii.gz ]] && [[ -r $refWM.nii.gz ]] && [[ -r $warp.nii.gz ]] ; then

    echo "  warping prior probability maps from the reference template to the structural"
    # loop over reference compartment priors to warp
    for refPrior in $refCSF $refGM $refWM ; do
      basePrior=$(basename $refPrior)
      # warp prior from reference space to structural space
      if [[ -r ${structMask}.nii.gz ]] ; then
        applywarp --rel --interp=spline -i $refPrior -r $workImg -m $structMask -w $warp -o $workDir/$basePrior
      else
        applywarp --rel --interp=spline -i $refPrior -r $workImg -w $warp -o $workDir/$basePrior
      fi
      fslmaths $workDir/$basePrior -thr 0 $workDir/$basePrior
    done

    # polish using priors
    echo "  create secondary compartments, masked by prior probability"
    priorCSF=$workDir/$(basename $refCSF)
    fslmaths $priorCSF -thr 0.3 -bin -mas $workDir/CSF $workDir/CSFcore
    priorGM=$workDir/$(basename $refGM)
    fslmaths $priorGM -thr 0.4 -bin -mas $workDir/GMall $workDir/GMcore
    priorWM=$workDir/$(basename $refWM)
    fslmaths $priorWM -thr 0.5 -bin -mas $workDir/WM $workDir/WMcore

    # copy relevant images from workDir to structDir
    imcp $workDir/CSFcore $workDir/GMcore $workDir/WMcore $structDir/

  else

    echo "  missing reference compartment priors or warp field, continuing without"

  fi


  echo "  eroding WM and CSF masks in structural space"
  # erode the WM and CSF
  voxSize=$(fslval $workDir/WM pixdim1 | awk '{val=100*$0; printf("%d\n", val+=val<0?-0.5:0.5)}')
  if [[ $voxSize -lt 55 ]] ; then
    fslmaths $workDir/WM -ero $workDir/WMero
    fslmaths $workDir/WMero -ero $workDir/WMero2
    fslmaths $workDir/GM -ero $workDir/GMero
    fslmaths $structMask -binv -add $workDir/CSF -bin -ero -mas $structMask $workDir/CSFero
    if [[ -f $workDir/WMcore.nii.gz ]] ; then
      fslmaths $workDir/WMero -mas $workDir/WMcore $workDir/WMeroCore
    fi
  else
    fslmaths $workDir/WM -s 1 -thr 0.8 -bin -mas $workDir/WM $workDir/WMero
    fslmaths $workDir/WM -s 1 -thr 0.9 -bin -mas $workDir/WM $workDir/WMero2
    fslmaths $workDir/GM -s 1 -thr 0.8 -bin -mas $workDir/GM $workDir/GMero
    fslmaths $structMask -binv -add $workDir/CSF -s 1 -thr 0.7 -bin -mas $workDir/CSF $workDir/CSFero
  fi

  # copy relevant images from workDir to structDir
  imcp $workDir/CSF $workDir/GM $workDir/WM $workDir/CSFero $workDir/GMero $workDir/WMero $workDir/WMero2 $workDir/GMall $structDir/
  [[ -f $workDir/subcortMask.nii.gz ]] && imcp $workDir/subcortMask $structDir/
  [[ -f $workDir/WMeroCore.nii.gz ]] && imcp $workDir/WMeroCore $structDir/

  # clean up
  rm -rf $workDir

  echo "  done"

fi


# hemimask
if [[ $instr =~ --hemimask$ ]] ; then
  base=$structDir/${structImg}
  echo "create hemisphere masks"

  # specify left and right hemisphere masks in reference space
  refMaskLeft=${refImg}_left_mask
  refMaskRight=${refImg}_right_mask

  # create these masks if they don't yet exist
  if [[ ! -r $refMaskLeft.nii.gz ]] || [[ ! -r $refMaskRight.nii.gz ]] ; then
    # make a mask with ones over the whole image
    fslmaths $refMask -mul 0 -add 1 $refMaskRight
    # find the cut between left and right
    voxCut=$(fslval $refMask "dim1" | awk '{print $1/2}' | awk '{print int($1)}')
    # split the
    fslmaths $refMaskRight -roi 0 $voxCut 0 -1 0 -1 0 -1 $refMaskLeft
    fslmaths $refMaskRight -roi $voxCut -1 0 -1 0 -1 0 -1 $refMaskRight
  fi

  # warp the hemisphere masks from reference to struct
  applywarp --rel --interp=nn -i $refMaskLeft -r $base -w $transDir/${refSpace}_to_${structImg}_warp -o $structDir/left
  applywarp --rel --interp=nn -i $refMaskRight -r $base -w $transDir/${refSpace}_to_${structImg}_warp -o $structDir/right

  echo "  done"

fi
