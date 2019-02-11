#!/usr/bin/env bash
set -e    # stop immediately on error
umask u+rw,g+rw # give group read/write permissions to all new files

# correct the intensity bias caused by RF field inhomogenieties


# ------------------------------ #
# Help
# ------------------------------ #

usage() {
cat <<EOF

rsn_biascorr.sh: Correct the intensity bias caused by RF field inhomogenieties

example:
      sh rsn_biascorr.sh funcIn.nii.gz funcOut.nii.gz
      sh rsn_biascorr.sh funcIn.nii.gz funcOut.nii.gz --rawmean=raw_mean.nii.gz

usage: $(basename $0)
      obligatory arguments
        <input func>      the input functional image to bias correct
      optional arguments
        <output func>     the output bias-corrected functional image
                          default: the same as the input image
        --rawmean=<image> if you specify a raw (not brain-extracted) functional
                          image here, it will be bias corrected too

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
    --rawmean=*)  rawMean="${a#*=}"; shift ;;
    *)            arg="$arg $a"; shift ;; # ordered arguments
  esac
done

# parse for obligatory arguments
#------------------------------
# extract arguments that don't start with "-"
argobl=$(echo $arg | tr " " "\n" | grep -v '^-') || true
# parse obligatory arguments from the non-dash arguments
funcIn=$(echo $argobl | awk '{print $1}')
funcOut=$(echo $argobl | awk '{print $2}')
# check if obligatory arguments have been set
if [[ -z $funcIn ]] ; then >&2 echo ""; >&2 echo "error: please specify the input functional image."; usage; exit 1; fi
# remove obligatory arguments from list of arguments
arg=$(echo $arg | tr " " "\n" | grep -v "$funcIn") || true
[[ -z $funcOut ]] && arg=$(echo $arg | tr " " "\n" | grep -v "$funcOut") || true
# check if no redundant arguments have been set
if [[ -n $arg ]] ; then >&2 echo ""; >&2 echo "unsupported arguments are given: $arg"; usage; exit 1; fi

# set defaults for optional arguments
#------------------------------
[[ -z $funcOut ]] && funcOut=$funcIn
[[ -z $rawMean ]] && rawMean=""

# derive the data directory
funcDir=$(dirname $funcIn)


# ------------------------------ #
# Do the work
# ------------------------------ #

# create a tmp directory to bias correct the functional image
rm -rf $funcDir/tmp.biascorr.*
tmpDir=$(mktemp -d "$funcDir/tmp.biascorr.XXXXXXXXXX")

# create a mean, copy the brain masks
echo "  creating mean functional image"
fslmaths $funcIn -Tmean $tmpDir/img
imcp ${funcIn}_brain_mask $tmpDir/img_brain_mask
imcp ${funcIn}_brain_mask_strict $tmpDir/img_brain_mask_strict

# ignore dark voxels
thr=$(fslstats $tmpDir/img -k $tmpDir/img_brain_mask_strict -P 50 | awk '{print $1/4}')
fslmaths $tmpDir/img -mas $tmpDir/img_brain_mask_strict -thr $thr -bin $tmpDir/img_brain_mask_strict
cluster --in=$tmpDir/img_brain_mask_strict --thresh=0.5 --connectivity=6 --minextent=10000 --no_table --oindex=$tmpDir/img_brain_mask_strict
fslmaths $tmpDir/img_brain_mask_strict -bin -s 2 -thr 0.6 -bin -mas $tmpDir/img_brain_mask_strict $tmpDir/img_brain_mask_strict
# and the super bright
thr=$(fslstats $tmpDir/img -k $tmpDir/img_brain_mask_strict -P 99.8)
fslmaths $tmpDir/img -uthr $thr -mas $tmpDir/img_brain_mask_strict -bin $tmpDir/img_brain_mask_strict

# smoothness definitions
sigma=3 #acquisition protocol dependent
FWHM=$(echo "2.3548 * $sigma" | bc)

# run robust bias correction on the EPI
sh $MRCATDIR/core/RobustBiasCorr.sh \
  --in=$tmpDir/img \
  --workingdir=$tmpDir/biascorr \
  --brainmask=$tmpDir/img_brain_mask_strict \
  --FWHM=$FWHM \
  --type=2 \
  --forcestrictbrainmask="FALSE" \
  --ignorecsf="FALSE"

# move and rename the bias field
immv $tmpDir/biascorr/img_bias ${funcIn}_bias

# apply the bias field
echo "  applying the bias field"
[[ -n $rawMean ]] && fslmaths $rawMean -div ${funcIn}_bias ${funcIn}_restore
fslmaths $tmpDir/img -div ${funcIn}_bias ${funcIn}_restore_brain
fslmaths $funcIn -div ${funcIn}_bias $funcOut

# create a new mean image
fslmaths $funcOut -Tmean ${funcOut}_mean

# clean up
rm -rf $tmpDir
