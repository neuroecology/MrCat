#!/usr/bin/env bash
set -e    # stop immediately on error
umask u+rw,g+rw # give group read/write permissions to all new files

# robust motion correction


# ------------------------------ #
# Help
# ------------------------------ #

usage() {
cat <<EOF

rsn_motionCorr.sh: motion correction to a robust reference image
  The reference image can be specified explicitely, created from new for the
  current run (default for run=1), or re-used from the first run (default for
  run>1).

example:
      sh rsn_motionCorr.sh image.nii.gz
      sh rsn_motionCorr.sh image.nii.gz --ref=refimage.nii.gz
      sh rsn_motionCorr.sh image.nii.gz  imageOut.nii.gz --ref=run1

usage: $(basename $0)
      obligatory arguments
        <input image>             the input image to process
      optional arguments
        <output image>            the output image file name
        --ref=<[image],new,run1>  [image]: path to a reference image
                                  new: create a new reference image for this run
                                    (default for run=1)
                                  run1: use a reference image from the first run
                                    (default for run>1)
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
    --ref=*)   refImg="${a#*=}"; shift ;;
    *)         arg="$arg $a"; shift ;; # ordered arguments
  esac
done

# parse for obligatory arguments
#------------------------------
# extract arguments that don't start with "-"
argobl=$(echo $arg | tr " " "\n" | grep -v '^-') || true
# parse obligatory arguments from the non-dash arguments
img=$(echo $argobl | awk '{print $1}')
imgOut=$(echo $argobl | awk '{print $2}')
# check if obligatory arguments have been set
if [[ -z $img ]] ; then >&2 echo ""; >&2 echo "error: please specify the input image."; usage; exit 1; fi
# remove img from list of arguments
arg=$(echo $arg | tr " " "\n" | grep -v "$img") || true
[[ -n $imgOut ]] && arg=$(echo $arg | tr " " "\n" | grep -v "$imgOut") || true
# check if no redundant arguments have been set
if [[ -n $arg ]] ; then >&2 echo ""; >&2 echo "unsupported arguments are given: $arg"; usage; exit 1; fi

# set defaults for optional arguments
#------------------------------
if [[ -z $refImg ]] ; then
  # extract the run number
  runIdx=$(echo ${img##*/} | grep -oh "run[1-9]" | cut -d"n" -f2)
  [[ -z $runIdx ]] && runIdx=1
  # set the refImg to 'new' or 'run1' depending on the run number
  [[ $runIdx -eq 1 ]] && refImg="new" || refImg="run1"
fi


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

# set output image name
[[ -z $imgOut ]] && imgOut=${img}_mc

# if requested take the reference image from the first run
if [[ $refImg == "run1" ]] ; then
  refImg=$(echo $img | sed 's@\run[1-9]@run1@g')_ref
  # give a warning if the requested reference image does not exist
  if [[ ! -f $refImg ]] && [[ ! -f $refImg.nii.gz ]] ; then
    >&2 printf '\nThe requested reference image from the first run cannot be found:\n  %s\n\n' $refImg
    exit 1
  else
    printf '    Using the reference image from the first run:\n      %s\n' $refImg
    # copy the reference image to the current run
    imcp $refImg ${img}_ref
    # try to copy the brain mask(s) along
    imcp ${refImg}_brain_mask ${img}_ref_brain_mask
    imcp ${refImg}_brain_mask_strict ${img}_ref_brain_mask_strict
  fi
fi


# if requested, create the reference image new for this run
if [[ $refImg == "new" ]] ; then

  # create a tmp directory to create a robust reference image
  rm -rf $imgDir/tmp.motioncorr.*
  tmpDir=$(mktemp -d "$imgDir/tmp.motioncorr.XXXXXXXXXX")

  # take the mean over all volumes
  echo "    creating mean image and refined brain mask"
  fslmaths $img -Tmean $tmpDir/mean

  # brain extract the mean image
  $MRCATDIR/core/bet_macaque.sh $tmpDir/mean -t T2star -m --refine

  # calculate the symmetric mean absolute percentage error compared to the mean (sMAPE)
  echo "    calculating symmetric mean absolute percentage error (sMAPE)"
  sh $MRCATDIR/core/smape.sh $img $tmpDir/mean --mask=$tmpDir/mean_brain_mask_strict --output=$tmpDir/sMAPE.txt
  echo "      done"

  # find the 50% volumes that best match the overall mean
  nVol=$(fslnvols $img)
  nRef=$(echo $nVol | awk '{$0=0.5*$0; printf "%d\n", ($0+=$0<0?-0.5:0.5) }')
  [[ $nRef -lt 1 ]] && nRef=1

  # split the timeseries in individual volumes
  echo "    creating an intermediate reference image based on the best volumes"
  mkdir -p $tmpDir/vols
  fslsplit $img $tmpDir/vols/vol -t

  # select the volumes with the best match to the mean to create a reference
  nl $tmpDir/sMAPE.txt | sort -nk2 | head -$nRef > $tmpDir/meanVols.txt
  refList=$(awk '{printf "'${tmpDir}'/vols/vol%04d\n", $1-1}' $tmpDir/meanVols.txt)
  fslmerge -t $tmpDir/ref4D $refList
  # create an intermediate mean reference image
  fslmaths $tmpDir/ref4D -Tmean $tmpDir/ref

  # motion correct the reference images
  echo "    running motion correction on these best volumes"
  mcflirt -in $tmpDir/ref4D -reffile $tmpDir/ref -out $tmpDir/ref4D_mc -spline_final

  # create an aligned mean reference image
  refImg=${img}_ref
  fslmaths $tmpDir/ref4D_mc -thr 0 $tmpDir/ref4D_mc
  fslmaths $tmpDir/ref4D_mc -Tmean $tmpDir/ref
  fslmaths $tmpDir/ref -thr 0 $refImg

  # brain extract the reference image (not used for motion correction)
  $MRCATDIR/core/bet_macaque.sh $refImg -t T2star -m --refine

  # clean up
  rm -rf $tmpDir

else

  # give a warning if the explicitely specified reference image does not exist
  if [[ ! -f $refImg ]] && [[ ! -f $refImg.nii.gz ]] ; then
    >&2 printf '\nThe specified reference image cannot be found:\n  %s\n\n' $refImg
    exit 1
  fi
  # copy the reference image to the current run
  imcp $refImg ${img}_ref

fi

# clean previous motion correction
rm -rf "$(dirname $imgOut)/$(basename ${imgOut%%.nii.gz})"*

# motion correct the full dataset
echo "    running motion correction on the full dataset"
mcflirt -in $img -reffile $refImg -out $imgOut -spline_final -mats -plots
fslmaths $imgOut -thr 0 $imgOut

echo ""
