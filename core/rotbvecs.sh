#!/usr/bin/env bash
set -e    # stop immediately on error

# ------------------------------ #
# usage
# ------------------------------ #

usage() {
cat <<EOF

rotbvecs.sh: apply a rigid-body rotation to a list of b-vectors. This allows you
  to rotate your bvecs along with the same transformation of the "raw" diffusion
  data (as long as you use the same rigid-body transformation matrix of course).
  WARNING: currently the rotation is simply taken from the full transformation
  matrix, including scaling and shearing effects! Accordingly, the results are
  only valid for rigid-body transformations, not for affine transformations.

Usage:    sh rotbvecs.sh -i <bvecs> -r <transform matrix> -o <output>

Example:  sh rotbvecs.sh -i ./bvecs -r rot.mat -o ./bvecs_rotated

Main transform_bvecs options:
  -i <bvecs input>      filename of the ascii file listing b-vectors [x y z]
                          If a "bvals" file is found in the same directory, then
                          this is copied along to the output directory
  -r <rotation matrix>  filename of the ascii file specifying the rigid-body
                          transformation matrix from which the rotation is
                          extracted.
  -o <bvecs output>     filename of the output file listing the rotated bvecs
                          If no output is specified "_rotated" is appended

EOF
}


#==============================
# overhead, argument parsing
#==============================

# if no arguments given, return the usage
if [[ $# -eq 0 ]] ; then usage; exit 0; fi

# if too few arguments given, return the usage, exit with error
if [[ $# -lt 6 ]] ; then >&2 usage; exit 1; fi

# set global defaults
args=""
bvecsOutputFile=""
bvalsOutputFile=""

# parse the input arguments
while [[ $# > 0 ]] ; do
  case "$1" in
      -i|--input)                       bvecsInputFile="$2"; shift 2 ;;
      -r|--rot|-t|--transform|--mat)    rotMatFile="$2"; shift 2 ;;
      -o|--output)                      bvecsOutputFile="$2"; shift 2 ;;
      *) args=$(echo "$args" "$1"); shift ;; # either obligatory or unknown option
  esac
done

# check if no redundant arguments have been set
if [[ -n $args ]] ; then
  >&2 echo ""; >&2 echo "unsupported arguments are given:" $args
  usage; exit 1
fi

# set argument dependent defaults
bvecsBase=$(basename $bvecsInputFile)
inputDir=$(dirname $bvecsInputFile)
if [[ -z $bvecsOutputFile ]] ; then
  base=$(echo ${bvecsBase%%.*})
  [[ -z $base ]] && base=bvecs
  ext=$(echo ${bvecsBase#*.})
  [[ -n $ext ]] && ext=".$ext"
  bvecsOutputFile="$inputDir/${base}_rotated${ext}"
fi
outputDir=$(dirname $bvecsOutputFile)
bvalsInputFile=$inputDir/bvals
if [[ -r $bvalsInputFile ]] ; then
  bvalsOutputFile="$outputDir/bvals"
  [[ $bvalsOutputFile == $bvalsInputFile ]] && bvalsOutputFile="$outputDir/bvals_rotated"
fi


#==============================
# main code
#==============================
echo "rotating bvecs"

# retrieve the xyz rows of the transformation matrix (ignoring the 4th column)
a=$(awk 'FNR == 1 {$NF=""; print}' $rotMatFile)
b=$(awk 'FNR == 2 {$NF=""; print}' $rotMatFile)
c=$(awk 'FNR == 3 {$NF=""; print}' $rotMatFile)

# read the bvecs file, for each dimension (3 x n)
X=($(awk 'FNR == 1' $bvecsInputFile))
Y=($(awk 'FNR == 2' $bvecsInputFile))
Z=($(awk 'FNR == 3' $bvecsInputFile))

# multiply the bvecs by the rotation matrix, loop over images (columns in bvecs)
str_Xrot=""
str_Yrot=""
str_Zrot=""
for idx in ${!X[*]} ; do
  XYZ=$(echo ${X[$idx]} ${Y[$idx]} ${Z[$idx]})
  Xrot=$(echo $XYZ $a | awk '{print ($1*$4) + ($2*$5) + ($3*$6)}')
  Yrot=$(echo $XYZ $b | awk '{print ($1*$4) + ($2*$5) + ($3*$6)}')
  Zrot=$(echo $XYZ $c | awk '{print ($1*$4) + ($2*$5) + ($3*$6)}')
  str_Xrot=$(echo $str_Xrot $Xrot)
  str_Yrot=$(echo $str_Yrot $Yrot)
  str_Zrot=$(echo $str_Zrot $Zrot)
done

# and write out the rotated bvecs to a file
echo $str_Xrot > $bvecsOutputFile
echo $str_Yrot >> $bvecsOutputFile
echo $str_Zrot >> $bvecsOutputFile
echo "done"

# and copy the bvals along
echo $bvalsOutputFile
if [[ -r $bvalsInputFile ]] && [[ -n $bvalsOutputFile ]] ; then
  cp $bvalsInputFile $bvalsOutputFile
else
  echo "please note, the bvals are not copied"
fi
