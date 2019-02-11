#!/usr/bin/env bash
set -e    # stop immediately on error
umask u+rw,g+rw # give group read/write permissions to all new files

# This is a simple little script to return the symmetric mean absolute
# percentage error of data (image or timeseries) against a reference. The script
# is so simple, it might be helpful as a template script too.


# ------------------------------ #
# Help
# ------------------------------ #

usage() {
cat <<EOF

smape.sh: return the symmetric mean absolute percentage error (sMAPE) for each volume to a reference

example:
      sh smape.sh data ref --mask=mask --output=data_sMAPE.txt

usage: $(basename $0)
      obligatory arguments
        <data> : input data (can be 4D)
        <reference> : a single volume to calculate the data error against
      optional arguments
        [--mask=<mask>] : a mask to calculate the sMAPE within
        [--output=<sMAPE.txt>] : the output text file (default: <data>_sMAPE.txt)
        [--outputimg=<img>] : path to the sMAPE image

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
    --outputimg=*)      outputImg="${a#*=}"; shift ;;
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
[[ -z $output ]] && output=${base%%.*}_sMAPE.txt

# set a masking option
[[ -n $mask ]] && maskOpt="-mas $mask" || maskOpt=""
[[ -n $mask ]] && maskOptShort="-m $mask" || maskOptShort=""


# ------------------------------ #
# Do the work
# ------------------------------ #

# create a temporary directory
#tmpDir=$dataDir/tmp_sMAPE
#mkdir -p $tmpDir
tmpDir=$(mktemp -d "$dataDir/tmp.smape.XXXXXXXXXX")

# calculate the absolute error of each volume in the data to the reference
fslmaths $data -sub $ref $maskOpt -abs $tmpDir/err

# take the absolute of the reference
fslmaths $ref $maskOpt -abs $tmpDir/absref

# take the sum of the absolute reference and absolute data
fslmaths $data $maskOpt -abs -add $tmpDir/absref $tmpDir/sum

# take the ratio of the error and the sum
fslmaths $tmpDir/err -div $tmpDir/sum $tmpDir/err

# average the symmetric absolute ratio error for each volume
fslmeants -i $tmpDir/err $maskOptShort -o $tmpDir/sMARE.txt

# convert the ratio to a percentage
awk '{print $1 * 100}' $tmpDir/sMARE.txt > $output

# output sMAPE image
if [[ -n $outputImg ]] ; then

  # store the sMAPE as a percentage image
  fslmaths $tmpDir/err $maskOpt -mul 100 $outputImg

fi

# clean up
rm -r $tmpDir
