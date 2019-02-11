#!/usr/bin/env bash
set -e    # stop immediately on error
umask u+rw,g+rw # give group read/write permissions to all new files

# This is a simple little script to return the mean absolute error of data
# (image or timeseries) against a reference. The script is so simple, it might
# be helpful as a template script too.


# ------------------------------ #
# Help
# ------------------------------ #

usage() {
cat <<EOF

mae.sh: return the mean absolute error (MAE) for each volume to a reference

example:
      sh mae.sh data ref --mask=mask --output=data_MAE.txt

usage: $(basename $0)
      obligatory arguments
        <data> : input data (can be 4D)
        <reference> : a single volume to calculate the data error against
      optional arguments
        [--mask=<mask>] : a mask to calculate the sMAPE within
        [--output=<MAE.txt>] : the output text file (default: <data>_MAE.txt)

EOF
}

# ------------------------------ #
# Housekeeping
# ------------------------------ #
# if no arguments given, or help is requested, return the usage
if [[ $# -eq 0 ]] || [[ $@ =~ --help ]] ; then usage; exit 0; fi

# if too few arguments given, return the usage, exit with error
if [[ $# -lt 2 ]] ; then >&2 usage; exit 1; fi

# set defaults
mask=""
output=""

# parse the input arguments
for a in "$@" ; do
  case $a in
    -m=*|--mask=*)      mask="${a#*=}"; shift ;;
    -o=*|--output=*)    output="${a#*=}"; shift ;;
    #-o=*|--option=*)   option="${a#*=}"; shift ;;
    *)                  arg="$arg $a"; shift ;; # ordered arguments
  esac
done

# parse for obligatory arguments
# extract arguments that don't start with "-"
argobl=$(echo $arg | tr " " "\n" | grep -v '^-') || true
# parse obligatory arguments from the non-dash arguments
data=$(echo $argobl | awk '{print $1}')
ref=$(echo $argobl | awk '{print $2}')

# check if obligatory arguments have been set
if [[ -z $data ]] ; then
  >&2 echo ""; >&2 echo "error: please specify the input data."
  usage; exit 1
fi
if [[ -z $ref ]] ; then
  >&2 echo ""; >&2 echo "error: please specify the reference image."
  usage; exit 1
fi

# remove img and base from list of arguments
arg=$(echo $arg | tr " " "\n" | grep -v "$data") || true
arg=$(echo $arg | tr " " "\n" | grep -v "$ref") || true

# check if no redundant arguments have been set
if [[ -n $arg ]] ; then
  >&2 echo ""; >&2 echo "unsupported arguments are given:" $arg
  usage; exit 1
fi

# retrieve data directory and base name
dataDir=$(dirname $data)
base=$(basename $data)

# set output if not specified
[[ -z $output ]] && output=${base%%.*}_MAE.txt


# ------------------------------ #
# Do the work
# ------------------------------ #

# create a temporary directory
tmpDir=$(mktemp -d "$dataDir/tmp.XXXXXXXXXX")

# calculate the absolute error of each volume in the data to the reference
fslmaths $data -sub $ref -abs $tmpDir/err

# average the absolute error for each volume
if [[ -n $mask ]] ; then
  fslmeants -i $tmpDir/err -m $mask -o $output
else
  fslmeants -i $tmpDir/err -o $output
fi

# clean up
rm -r $tmpDir
