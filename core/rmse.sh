#!/usr/bin/env bash
set -e    # stop immediately on error
umask u+rw,g+rw # give group read/write permissions to all new files

# This is a simple little script to return the root-mean-square-error of data
# (image or timeseries) against a reference. The script is so simple, it might
# be helpful as a template script too.


# ------------------------------ #
# Help
# ------------------------------ #

usage() {
cat <<EOF

rmse.sh: return the root-mean-square-error (RMSE) for each volume to a reference

example:
      sh rmse.sh data ref --mask=mask --output=data_RMSE.txt

usage: $(basename $0)
      obligatory arguments
        <data> : input data (can be 4D)
        <reference> : a single volume to calculate the data error against
      optional arguments
        [--mask=<mask>] : a mask to calculate the RMSE within
        [--output=<RMSE.txt>] : the output text file (default: <data>_RMSE.txt)

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
[[ -z $output ]] && output=${base%%.*}_RMSE.txt


# ------------------------------ #
# Do the work
# ------------------------------ #

# create a temporary directory
tmpDir=$(mktemp -d "$dataDir/tmp.XXXXXXXXXX")

# calculate the square error of each volume in the data to the reference
fslmaths $data -sub $ref -sqr $tmpDir/img

# average the square error for each volume
if [[ -n $mask ]] ; then
  fslmeants -i $tmpDir/img -m $mask -o $tmpDir/MSE.txt
else
  fslmeants -i $tmpDir/img -o $tmpDir/MSE.txt
fi

# take the root of the mean square error for each volume
awk '{print sqrt($1)}' $tmpDir/MSE.txt > $output

# clean up
rm -r $tmpDir
