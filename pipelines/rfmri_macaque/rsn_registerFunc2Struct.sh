#!/usr/bin/env bash
set -e    # stop immediately on error
umask u+rw,g+rw # give group read/write permissions to all new files

# register the functional image to the structural (and bias correct)

# TODO: this could be improved by either
#   1) using fieldmaps
#   2) using ANTs, see the new awake fMRI pipeline

# ------------------------------ #
# Help
# ------------------------------ #

usage() {
cat <<EOF

rsn_registerFunc2Struct.sh: Register the functional image to the structural

example:
      sh rsn_registerFunc2Struct.sh funcIn.nii.gz struct.nii.gz funcOut.nii.gz

usage: $(basename $0)
      obligatory arguments
        <input func>      the input functional image to register
        <struct>          the structural image (preferable bias corrected)
        <output func>     the output brain-extracted functional image
      optional arguments
        --transdir=<dir>    the directory where to store the transformations
        --ref=<run1,indep>  set whether the registration is referenced from the
                            first run ('run1', default), or estimated for each
                            run independently ('indep')

EOF
}


# ------------------------------ #
# Housekeeping
# ------------------------------ #

# if no arguments given, or help is requested, return the usage
if [[ $# -eq 0 ]] || [[ $@ =~ --help ]] ; then usage; exit 0; fi
# if too few arguments given, return the usage, exit with error
if [[ $# -lt 3 ]] ; then >&2 usage; exit 1; fi

# parse the input arguments
#------------------------------
for a in "$@" ; do
  case $a in
    --transdir=*)   transDir="${a#*=}"; shift ;;
    --ref=*)        refRun="${a#*=}"; shift ;;
    *)              arg="$arg $a"; shift ;; # ordered arguments
  esac
done

# parse for obligatory arguments
#------------------------------
# extract arguments that don't start with "-"
argobl=$(echo $arg | tr " " "\n" | grep -v '^-') || true
# parse obligatory arguments from the non-dash arguments
funcIn=$(echo $argobl | awk '{print $1}')
struct=$(echo $argobl | awk '{print $2}')
funcOut=$(echo $argobl | awk '{print $3}')
# check if obligatory arguments have been set
if [[ -z $funcIn ]] ; then >&2 echo ""; >&2 echo "error: please specify the input functional image."; usage; exit 1; fi
if [[ -z $struct ]] ; then >&2 echo ""; >&2 echo "error: please specify the structural image."; usage; exit 1; fi
if [[ -z $funcOut ]] ; then >&2 echo ""; >&2 echo "error: please specify the output functional image."; usage; exit 1; fi
# remove obligatory arguments from list of arguments
arg=$(echo $arg | tr " " "\n" | grep -v "$funcIn") || true
arg=$(echo $arg | tr " " "\n" | grep -v "$struct") || true
arg=$(echo $arg | tr " " "\n" | grep -v "$funcOut") || true
# check if no redundant arguments have been set
if [[ -n $arg ]] ; then >&2 echo ""; >&2 echo "unsupported arguments are given: $arg"; usage; exit 1; fi

# set defaults for optional arguments
#------------------------------
[[ -z $refRun ]] && refRun="run1"

# derive the data directories
structDir=$(dirname $struct)
funcDir=$(dirname $funcOut)

# retrieve the run index
runIdx=$(echo ${funcIn##*/} | grep -oh "run[1-9]" | cut -d"n" -f2)

# if no run index is found, set to 0
[[ -z $runIdx ]] && runIdx=0

# set the transformation directory if not explicitely specified
if [[ -z $transDir ]] ; then
  if [[ $runIdx -eq 0 ]] ; then
    # when only a single run is found (without a run index),
    # store the transforms at the same level as the functional directory
    mkdir -p $funcDir/../transform
    transDir=$(cd $funcDir/../transform; pwd)
  else
    # store the transforms under the functional run directory
    transDir=$funcDir/transform
  fi
fi
mkdir -p $transDir


# ------------------------------ #
# Here be dragons
# ------------------------------ #

# register the functional to the structural
if [[ $runIdx -lt 2 ]] || [[ $refRun == "indep" ]] ; then

  # create a mean and rename to make the naming of the transforms more straightforward
  echo "  creating mean functional image to register"
  fslmaths $funcIn -Tmean $funcOut

  # register to the structural
  sh ${MRCATDIR}/core/register_EPI_T1.sh \
    --epi=$funcOut \
    --t1=$struct \
    --t1brain=${struct}_brain \
    --t1wm=$structDir/WM \
    --transdir=$transDir \
    --all

  # rename the mean back the the a more original name
  immv $funcOut ${funcIn}_mean

else

  # create a mean
  echo "  creating mean functional image"
  fslmaths $funcIn -Tmean ${funcIn}_mean

  # rely on the first run for the registration to the structural
  transDirRun1=$(echo $transDir | sed 's@\run[1-9]@run1@g')

  # copy transform directory
  echo "  copying registration parameters and brain mask from run1 to run$runIdx"
  mkdir -p $transDir
  for fNameRun1 in $transDirRun1/* ; do
    fName=$(basename "$(echo $fNameRun1 | sed "s@\run[1-9]@run$runIdx@g")")
    cp $fNameRun1 $transDir/$fName
  done

  # copy resampled structural images
  funcDirRun1=$(echo $funcDir | sed 's@\run[1-9]@run1@g')
  cp $funcDirRun1/struct* $funcDir/

  # copy brain mask
  funcOutRun1=$(echo $funcOut | sed 's@\run[1-9]@run1@g')
  imcp ${funcOutRun1}_brain_mask ${funcOut}_brain_mask
  imcp ${funcOutRun1}_brain_mask_strict ${funcOut}_brain_mask_strict

fi

# apply the brain mask
echo "  applying the brain mask"
fslmaths $funcIn -mas ${funcOut}_brain_mask $funcOut
