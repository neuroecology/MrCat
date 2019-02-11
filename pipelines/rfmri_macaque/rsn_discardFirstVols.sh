#!/usr/bin/env bash
set -e    # stop immediately on error
umask u+rw,g+rw # give group read/write permissions to all new files

# cut out the first n seconds (default: 10) until a steady state of radio-frequency excitation


# ------------------------------ #
# Help
# ------------------------------ #

usage() {
cat <<EOF

rsn_discardFirstVols.sh: Discard first volumes until steady RF excitation state

example:
      sh rsn_discardFirstVols.sh image.nii.gz
      sh rsn_discardFirstVols.sh image.nii.gz --seconds=15
      sh rsn_discardFirstVols.sh image.nii.gz -f

usage: $(basename $0)
      obligatory arguments
        <input image>     the input image to process
      optional arguments
        --seconds=<int>   how many seconds (default: 10) to discard at the start
        -f,--force        force to redo, even if done before

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
    -s=*|--seconds=*)   nSecond="${a#*=}"; shift ;;
    -f|--force)         flgForce=1; shift ;;
    *)                  arg="$arg $a"; shift ;; # ordered arguments
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
[[ -z $nSecond ]] && nSecond=10
[[ -z $flgForce ]] && flgForce=0


# ------------------------------ #
# Do the work
# ------------------------------ #

# retrieve the TR
TR=$(fslval $img "pixdim4")

# determine the number of volumes to cut: divide nSecond by TR and round up
nVol=$(echo $nSecond $TR | awk '{n=$1/$2; print int(n)+(n>int(n))}')

# specify the file name for volumes that are discarded
firstVols=${img%%.nii.gz}_firstvols.nii.gz

# if requested to force repeat the discarding, adjust the name
if [[ $flgForce -eq 1 ]] ; then
  while [[ -f $firstVols ]] ; do
    firstVols=${firstVols%%.nii.gz}+.nii.gz
  done
fi

# give a warning if the logfile suggest the reorientation has been done already
# otherwise, reorient
if [[ -f $firstVols ]] ; then

  # count how many volumes were already discarded
  nVolAlreadyDiscarded=$(fslnvols $firstVols)

  # if this does not match the new request, do it again
  if [[ $nVol -ne $nVolAlreadyDiscarded ]] ; then

    echo "    The first $nVolAlreadyDiscarded volumes from these data have been previously discarded"
    echo "    The orignal dataset will be restored and cut again, overwriting previous cuts"
    echo "    If instead you want to discard volumes iteratively, please use the -f,--force option"

    # restore the original dataset
    fslmerge -t $img $img ${firstVols%%.nii.gz}*.nii.gz

  else

    # leave at it is
    echo "    The first $nVol have already been discarded and saved as:"
    echo "      $firstVols"
    echo "    This step won't be repeated. If instead you want to discard"
    echo "    volumes iteratively, please use the -f,--force option."

    # return early, without doing anything
    exit 0

  fi

fi


# cut the first n volumes and save the rest in a separate image
echo "    cut the first $nVol volumes and store separately"
fslroi $img $firstVols 0 $nVol
fslroi $img $img $nVol -1
echo "      done"
