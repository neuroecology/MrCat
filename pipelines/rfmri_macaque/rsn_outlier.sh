#!/usr/bin/env bash
set -e    # stop immediately on error
umask u+rw,g+rw # give group read/write permissions to all new files

# cut out the first n seconds (default: 15) until a steady state of radio-frequency excitation


# ------------------------------ #
# Help
# ------------------------------ #

usage() {
cat <<EOF

rsn_cutJumps.sh: cut data timeseries at large jumps based on symmetric mean
                 absolute percentage error (sMAPE)

example:
      sh rsn_cutJumps.sh image.nii.gz
      sh rsn_cutJumps.sh image.nii.gz --thr=4 --iqr=8 --detect
      sh rsn_cutJumps.sh image.nii.gz --thr=4 --iqr=15 --detect --cut
      sh rsn_cutJumps.sh image.nii.gz --cut
      sh rsn_cutJumps.sh image.nii.gz --cut --cutother=motionParam.txt
      sh rsn_cutJumps.sh image.nii.gz --cut --idxon=0 --idxoff=639

usage: $(basename $0)
      obligatory arguments
        <input image>     the input image to process
      optional arguments
        --ref=<image> name of the reference image, default: ${img}_ref
                      when set to "mean", the mean of the run is calculated
        --iqr=<int>   n x upper-inter-quartile range, to define sMAPE outliers
                      (please note, the upper-IQR is about half the full IQR)
                      default: 8
        --thr=<val>   hard threshold of maximum sMAPE allowed
                      default: 4
        --detect      only detect, but do not apply outlier cuts
        --cut         fix and cut outliers
        --cutother=<file> apply same cuts to a text file (e.g. motion confounds)
                      multiple files can be specified in a '@'-delimited list
        --cutstart    start of the good segment as a volume index (0-based).
                      This overrides the cut defined by --detect.
        --cutstop     end of the good segment as a volume index (0-based).
                      This overrides the cut defined by --detect.
      internal arguments
        --getref=<tmpDir>

EOF
}


# ------------------------------ #
# Housekeeping
# ------------------------------ #

# if no arguments given, or help is requested, return the usage
if [[ $# -eq 0 ]] || [[ $@ =~ --help ]] ; then usage; exit 0; fi
# if too few arguments given, return the usage, exit with error
if [[ $# -lt 1 ]] ; then >&2 usage; exit 1; fi

# parse the input arguments
#------------------------------
for a in "$@" ; do
  case $a in
    --ref=*)      refImg="${a#*=}"; shift ;;
    --iqr=*)      iqr="${a#*=}"; shift ;;
    --thr=*)      thr="${a#*=}"; shift ;;
    --detect)     flgDetect=1; shift ;;
    --cut)        flgCut=1; shift ;;
    --cutother=*) cutOther="${a#*=}"; shift ;;
    --cutstart=*) idxOn="${a#*=}"; shift ;;
    --cutstop=*)  idxOff="${a#*=}"; shift ;;
    --getref=*)   flgGetRef=1; tmpDir="${a#*=}"; shift ;;
    *)            arg="$arg $a"; shift ;; # ordered arguments
  esac
done

# parse for obligatory arguments
#------------------------------
# extract arguments that don't start with "-"
argobl=$(echo $arg | tr " " "\n" | grep -v '^-') || true
# parse obligatory arguments from the non-dash arguments
img=$(echo $argobl | awk '{print $1}')
# check if obligatory arguments have been set
if [[ -z $img ]] ; then >&2 echo ""; >&2 echo "error: please specify the input image."; usage; exit 1; fi
# remove img from list of arguments
arg=$(echo $arg | tr " " "\n" | grep -v "$img") || true
# check if no redundant arguments have been set
if [[ -n $arg ]] ; then >&2 echo ""; >&2 echo "unsupported arguments are given: $arg"; usage; exit 1; fi

# set defaults for optional arguments
#------------------------------
[[ -z $refImg ]] && refImg="ref"
[[ -z $iqr ]] && iqr=8
[[ -z $thr ]] && thr=4
if [[ -n $idxOn ]] || [[ -n $idxOff ]] ; then
  if [[ -n $flgDetect ]] && [[ $flgDetect -eq 1 ]] ; then
    echo "Excplicit cuts are requested through --cutstart/--cutstop."
    echo "This renders the detection phase redundent."
    echo "--detect will be ignored, only --cut will be executed."
  fi
  flgDetect=0
  flgCut=1
fi
if [[ -z $flgDetect ]] && [[ -z $flgCut ]] ; then
  flgDetect=1
  flgCut=1
else
  [[ -z $flgDetect ]] && flgDetect=0
  [[ -z $flgCut ]] && flgCut=0
fi
[[ -z $flgGetRef ]] && flgGetRef=0
# retrieve the current folder
# thisDir=$MRCATDIR/pipelines/rfmri_macaque
thisDir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )


# ------------------------------ #
# Here be dragons
# ------------------------------ #

# unpack the image name
imgDir=$(dirname $img)
img=$(basename $img)
imgExt=${img#*.}
img=${img%%.*}
[[ $imgExt != $img ]] && imgExt=".$imgExt" || imgExt=""
img=$imgDir/$img

# look for an original copy of the data
imgOrig=${img}_orig$imgExt


# get the reference image and brain mask
if [[ $flgGetRef -eq 1 ]] ; then

  # find a reference image
  if [[ $refImg == "ref" ]] ; then
    [[ -f ${img}_ref.nii.gz ]] && imcp ${img}_ref $tmpDir/ref || refImg="mean"
    [[ -f ${img}_ref_brain_mask.nii.gz ]] && imcp ${img}_ref_brain_mask $tmpDir/ref_brain_mask
    [[ -f ${img}_ref_brain_mask_strict.nii.gz ]] && imcp ${img}_ref_brain_mask_strict $tmpDir/ref_brain_mask_strict
  fi

  # find or create a mean reference image
  if [[ $refImg == "mean" ]] ; then
    # take the mean over all volumes
    if [[ -f ${img}_mean.nii.gz ]] ; then
      # simply copy the available mean
      imcp ${img}_mean $tmpDir/ref
    else
      echo "    creating a mean image"
      fslmaths $img -Tmean $tmpDir/ref
    fi
    [[ -f ${img}_mean_brain_mask.nii.gz ]] && imcp ${img}_mean_brain_mask $tmpDir/ref_brain_mask
    [[ -f ${img}_mean_brain_mask_strict.nii.gz ]] && imcp ${img}_mean_brain_mask_strict $tmpDir/ref_brain_mask_strict
  fi

  # copy the explicitely specified reference image
  if [[ $refImg != "ref" ]] && [[ $refImg != "mean" ]] ; then
    if [[ -f ${refImg}.nii.gz ]] ; then
      imcp $refImg $tmpDir/ref
    else
      >&2 printf "\nspecified reference image does not exist:  %s\n\n" $refImg
      exit 1
    fi
    [[ -f ${refImg}_brain_mask.nii.gz ]] && imcp ${refImg}_brain_mask $tmpDir/ref_brain_mask
    [[ -f ${refImg}_brain_mask_strict.nii.gz ]] && imcp ${refImg}_brain_mask_strict $tmpDir/ref_brain_mask_strict
  fi

  # find or create a brain mask
  if [[ ! -f $tmpDir/ref_brain_mask_strict.nii.gz ]] ; then
    if [[ -f $tmpDir/ref_brain_mask.nii.gz ]] ; then
      # create a strict brain mask without any dark voxels
      fslmaths $tmpDir/ref_brain_mask -ero $tmpDir/ref_brain_mask_strict
      thrMedian=$(fslstats $tmpDir/ref -k $tmpDir/ref_brain_mask_strict -P 50 | awk '{print $1/4}')
      fslmaths $tmpDir/ref -mas $tmpDir/ref_brain_mask -thr $thrMedian -bin $tmpDir/ref_brain_mask_strict
    else
      # brain extract the reference image
      $MRCATDIR/core/bet_macaque.sh $tmpDir/ref -t T2star -m --refine
    fi
  fi

  # copy the reference image and masks back for future use
  if [[ $refImg == "ref" ]] ; then
    refOrigBase=${img}_ref
  elif [[ $refImg == "mean" ]] ; then
    refOrigBase=${img}_mean
  else
    refOrigBase=$refImg
  fi
  [[ ! -f $refOrigBase.nii.gz ]] && imcp $tmpDir/ref $refOrigBase
  [[ ! -f ${refOrigBase}_brain_mask.nii.gz ]] && imcp $tmpDir/ref_brain_mask ${refOrigBase}_brain_mask
  [[ ! -f ${refOrigBase}_brain_mask_strict.nii.gz ]] && imcp $tmpDir/ref_brain_mask_strict ${refOrigBase}_brain_mask_strict

  # return to caller
  exit 0

fi



# detect singular outliers
if [[ $flgDetect -eq 1 ]] ; then
  echo ""
  echo "  phase 1: detect outliers"

  # detect jumps and outliers based on the original data
  if [[ -r $imgOrig ]] || [[ -r $imgOrig.nii.gz ]] ; then
    imgDetect=$imgOrig
  else
    imgDetect=$img
  fi

  # create a tmp directory to detect outliers
  rm -rf $imgDir/tmp.detectoutlier.*
  tmpDir=$(mktemp -d "$imgDir/tmp.detectoutlier.XXXXXXXXXX")

  # get the reference image
  sh $thisDir/rsn_outlier.sh $img --ref=$refImg --getref=$tmpDir

  # shift the timeseries one sample to calculate the derivative error
  echo "    shifting the timeseries to calculate the derivative"
  nVol=$(fslnvols $imgDetect)
  fslroi $imgDetect $tmpDir/secondVol 1 1
  fslroi $imgDetect $tmpDir/shiftVol 0 $((nVol-1))
  fslmerge -t $tmpDir/shiftVol $tmpDir/secondVol $tmpDir/shiftVol

  # take the symmetric mean absolute percentage error on the derivative (sMAPE)
  echo "    calculating symmetric mean absolute percentage error on the derivative (sMAPE)"
  sh $MRCATDIR/core/smape.sh $imgDetect $tmpDir/shiftVol --mask=$tmpDir/ref_brain_mask_strict --output=$tmpDir/sMAPEderiv.txt
  sh $MRCATDIR/core/cut_outlier.sh $imgDetect $tmpDir/sMAPEderiv.txt --thr=4 --iqr=$iqr --metric > $tmpDir/sMAPEderiv_IQRscaled.txt
  echo "      done"

  # calculate the symmetric mean absolute percentage error (sMAPE)
  echo "    calculating symmetric mean absolute percentage error to the reference (sMAPE)"
  sh $MRCATDIR/core/smape.sh $imgDetect $tmpDir/ref --mask=$tmpDir/ref_brain_mask_strict --output=${img}_sMAPE.txt
  sh $MRCATDIR/core/cut_outlier.sh $imgDetect ${img}_sMAPE.txt --thr=4 --iqr=$iqr --metric > ${img}_sMAPE_IQRscaled.txt
  echo "      done"

  # combine the two outlier detection methods
  paste $tmpDir/sMAPEderiv_IQRscaled.txt ${img}_sMAPE_IQRscaled.txt | awk '{if($1>$2) print $1; else print $2}' > ${img}_sMAPE_exclDetrend.txt

  # detrend, ignoring outliers
  echo "    detrending the timeseries (ignoring outliers)"
  # detrend while ignoring outliers
  fnameIn="$imgDetect.nii.gz"
  fnameOut="$tmpDir/detrend.nii.gz"
  fnameOutlier="${img}_sMAPE_exclDetrend.txt"
  $MATLABBIN/matlab -nodisplay -nosplash -r "addpath('$MRCATDIR');setupMrCat;rsn_detrend('$fnameIn','$fnameOut','$fnameOutlier');exit"

  # calculate the symmetric mean absolute percentage error (sMAPE)
  echo "    calculating symmetric mean absolute percentage error to the reference (sMAPE)"
  sh $MRCATDIR/core/smape.sh $tmpDir/detrend $tmpDir/ref --mask=$tmpDir/ref_brain_mask_strict --output=${img}_sMAPE.txt --outputimg=${img}_sMAPE
  sh $MRCATDIR/core/cut_outlier.sh $imgDetect ${img}_sMAPE.txt --thr=$thr --iqr=$iqr --metric > ${img}_sMAPE_IQRscaled.txt
  thrIQR=$(sh $MRCATDIR/core/cut_outlier.sh $imgDetect ${img}_sMAPE.txt --thr=$thr --iqr=$iqr --cutthr)
  fslmaths ${img}_sMAPE -sub "$(echo $thrIQR | awk '{print $1}')" -mas $tmpDir/ref_brain_mask_strict -div "$(echo $thrIQR | awk '{print $2}')" ${img}_sMAPE
  echo "      done"

  # identify outliers to fix
  nMax=2 #maximally 2 outliers in a row
  fixOutlierList=$(awk -v nmax=$nMax '{if($1>0) n++; else {if(n>nmax) n=0; else {while(n>0&&n<=nmax) {print NR-1-n; --n}}}} END {while(n>0&&n<=nmax) {print NR-n; --n}}' ${img}_sMAPE_IQRscaled.txt)

  # report outliers
  if [[ -n $fixOutlierList ]] ; then

    if [[ $(echo $fixOutlierList | wc -w | awk '{print $1}') -eq 1 ]] ; then
      echo "    fixable outlier found at volume:" $fixOutlierList
    else
      echo "    fixable outliers found at volumes:" $fixOutlierList
    fi

    # create a fake sMAPE file pretending those volumes are fixed
    echo $fixOutlierList | tr ' ' '\n' | awk '{print $1+1}' > $tmpDir/fixOutlierList.txt
    awk 'NR==FNR{a[$1]++;next} { if(FNR in a){print 0} else{print} }' $tmpDir/fixOutlierList.txt ${img}_sMAPE.txt > $tmpDir/sMAPEref_fixed.txt

    # report as if these volumes were already fixed
    echo "    remaining outliers:"
    sh $MRCATDIR/core/cut_outlier.sh $imgDetect $tmpDir/sMAPEref_fixed.txt --thr=$thr --iqr=$iqr --report

  else

    # give full report
    sh $MRCATDIR/core/cut_outlier.sh $imgDetect ${img}_sMAPE.txt --thr=$thr --iqr=$iqr --report

  fi

  # clean up
  rm -r $tmpDir

fi



# requested to cut jumps, but no outliers are found
if [[ $flgCut -eq 1 ]] ; then
  echo ""
  echo "  phase 2: fix and cut outliers"

  # retreive the cut values and number of good volumes
  if [[ -n $idxOn ]] || [[ -n $idxOff ]] ; then
    # if the idxOn and idxOff are explicitly specified

    # number of volumes of the original data file
    nVol=$(fslnvols $imgOrig)

    # set the volume indices (0-based) to cut
    [[ -z $idxOn ]] && idxOn=0
    [[ -z $idxOff ]] && idxOff=$((nVol-1))

    # determine the number of good volumes
    nGood=$((idxOff-idxOn+1))

  else

    # retrieve the cut values from the sMAPE file
    cutVal=$(sh $MRCATDIR/core/cut_outlier.sh $imgOrig ${img}_sMAPE.txt --thr=$thr --iqr=$iqr --detect)
    nGood=$(echo $cutVal | awk '{print $3}')
    nVol=$(echo $cutVal | awk '{print $4}')

  fi

  # return quickly, if possible
  if [[ $nGood -eq $nVol ]] ; then

    # report and remove the original copy if no longer valid
    sh $MRCATDIR/core/cut_outlier.sh $imgOrig ${img}_sMAPE.txt --thr=$thr --iqr=$iqr

    # restore any other parameter file (e.g. motion confounds)
    for cutFile in ${cutOther//@/ } ; do

      # specify the name of the back-up copy of the original file
      cutFileExt=${cutFile##*.}
      [[ -n $cutFileExt ]] && cutFileExt=".$cutFileExt"
      cutFileOrig=${cutFile%.*}_orig${cutFileExt}

      # restore a potential back-up of the original to avoid confusion
      [[ -f $cutFileOrig ]] && mv $cutFileOrig $cutFile

    done

    # return to caller
    exit 0

  fi

  # identify outliers to fix
  nMax=2 #maximally 2 outliers in a row
  fixOutlierList=$(awk -v nmax=$nMax '{if($1>0) n++; else {if(n>nmax) n=0; else {while(n>0&&n<=nmax) {print NR-1-n; --n}}}} END {while(n>0&&n<=nmax) {print NR-n; --n}}' ${img}_sMAPE_IQRscaled.txt)

  # fix outliers
  if [[ -n $fixOutlierList ]] ; then

    # store a copy of the original
    if [[ -r $imgOrig ]] || [[ -r $imgOrig.nii.gz ]] ; then
      echo "  backup of original timeseries found, not overwriting"
    else
      echo "  backing up the original timeseries"
      imcp $img $imgOrig
    fi

    # fix outliers
    echo "    fixing outliers by interpolation"
    fnameIn="$imgOrig.nii.gz"
    fnameOut="$img.nii.gz"
    fnameOutlier="${img}_sMAPE_IQRscaled.txt"
    fnameErr="${img}_sMAPE.nii.gz"
    $MATLABBIN/matlab -nodisplay -nosplash -r "addpath('$MRCATDIR');setupMrCat;rsn_fixOutlier('$fnameIn','$fnameOut','$fnameOutlier','$fnameErr',$nMax,'linear');exit"

    # re-detect and/or apply cuts
    if [[ -n $idxOn ]] || [[ -n $idxOff ]] ; then

      # apply the explicitely specified cuts
      sh $MRCATDIR/core/cut_outlier.sh $img --cutstart=$idxOn --cutstop=$idxOff --nobackup

    else
      # re-do outlier detection, if cut values are not explicitely specified

      # create a tmp directory to detect outliers
      rm -rf $imgDir/tmp.cutoutlier.*
      tmpDir=$(mktemp -d "$imgDir/tmp.cutoutlier.XXXXXXXXXX")

      # get the reference image
      sh $thisDir/rsn_outlier.sh $img --ref=$refImg --getref=$tmpDir

      # detrend while ignoring outliers
      echo "    detrending the timeseries (ignoring outliers)"
      fnameIn="$img.nii.gz"
      fnameOut="$tmpDir/detrend.nii.gz"
      fnameOutlier="${img}_sMAPE_exclDetrend.txt"
      $MATLABBIN/matlab -nodisplay -nosplash -r "addpath('$MRCATDIR');setupMrCat;rsn_detrend('$fnameIn','$fnameOut','$fnameOutlier');exit"

      # re-run the sMAPE outlier detection...
      echo "    re-calculating the symmetric mean absolute percentage error to the reference (sMAPE)"
      sh $MRCATDIR/core/smape.sh $tmpDir/detrend $tmpDir/ref --mask=$tmpDir/ref_brain_mask_strict --output=${img}_sMAPE_outlierFixed.txt
      echo "      done"

      # apply the outlier cuts based on the new sMAPE
      #   please not that this is run with the --nobackup option to prevent the
      #   original backup being overwritten
      cutVal=$(sh $MRCATDIR/core/cut_outlier.sh $img ${img}_sMAPE_outlierFixed.txt --thr=$thr --iqr=$iqr --detect)
      sh $MRCATDIR/core/cut_outlier.sh $img ${img}_sMAPE_outlierFixed.txt --thr=$thr --iqr=$iqr --nobackup

      # clean up
      rm -r $tmpDir

    fi

  else

    # apply the outlier cuts
    if [[ -z $idxOn ]] && [[ -z $idxOff ]] ; then

      # apply the outlier cuts based on the sMAPE file
      cutVal=$(sh $MRCATDIR/core/cut_outlier.sh $img ${img}_sMAPE.txt --thr=$thr --iqr=$iqr --detect)
      sh $MRCATDIR/core/cut_outlier.sh $img ${img}_sMAPE.txt --thr=$thr --iqr=$iqr

    else

      # apply the explicitely specified cuts
      sh $MRCATDIR/core/cut_outlier.sh $img --cutstart=$idxOn --cutstop=$idxOff

    fi

  fi

  # apply the outlier cuts to any other parameter file (e.g. motion confounds)
  for cutFile in ${cutOther//@/ } ; do

    # specify the name for a back-up copy of the original file
    cutFileExt=${cutFile##*.}
    [[ -n $cutFileExt ]] && cutFileExt=".$cutFileExt"
    cutFileOrig=${cutFile%.*}_orig${cutFileExt}
    cutFileTmp=${cutFile%.*}_tmp${cutFileExt}

    # retrieve the outlier cuts, if not explicitely specified
    if [[ -z $idxOn ]] && [[ -z $idxOff ]] ; then
      idxOn=$(echo $cutVal | awk '{print $1+1}')
      idxOff=$(echo $cutVal | awk '{print $2+1}')
      nGood=$(echo $cutVal | awk '{print $3}')
      nVol=$(echo $cutVal | awk '{print $4}')
    fi

    # check if the dataset was cut
    if [[ $nGood -lt $nVol ]] ; then

      # restore an original copy, or store a new copy
      [[ -f $cutFileOrig ]] && cp $cutFileOrig $cutFile || cp $cutFile $cutFileOrig

      # cut the requested file
      awk -v idxOn=$idxOn -v idxOff=$idxOff '(NR>=idxOn && NR<=idxOff){print $0}' $cutFile > $cutFileTmp
      mv $cutFileTmp $cutFile

    else

      # restore a potential back-up of the original to avoid confusion
      [[ -f $cutFileOrig ]] && mv $cutFileOrig $cutFile

    fi

  done

fi

echo " " > /dev/null # weirdly, I've experienced that this function can unexpectedly return an error status. This will help overcome that false negative.
