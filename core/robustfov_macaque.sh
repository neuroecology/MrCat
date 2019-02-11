#!/usr/bin/env bash
set -e    # stop immediately on error

# ------------------------------ #
# usage
# ------------------------------ #

usage() {
cat <<EOF

robustfov_macaque.sh: cropping the field-of-view for macaque in-vivo structural images

Usage:    sh robustfov_macaque.sh <input> [<output>] [options]

Main robustfov_macaque options:
  <input>     input image, obligatory
  <output>    base name of the output image, <input> is taken when not specified

Options specifically tailored for bet_macaque:
  -t <type>   type of image: "T1" (default), "T2star". "T2" is not yet supported. Determines defaults of options.
  -m <mm1 mm2 mm3>      desired image size in mm. Default: 128 128 64
  -v <vox1 vox2 vox3>   desired image size in voxels (incompatible with '-m' and vice versa)
  -f          force the desired voxel dimensions
  -c          use the mask centroid, instead of its outer edges, to determine the field-of-view

Please note that this script does not work like the general robustfov

EOF
}


#==============================
# overhead, argument parsing
#==============================

# if no arguments given, return the usage
if [[ $# -eq 0 ]] ; then usage; exit 0; fi

# if too few arguments given, return the usage, exit with error
if [[ $# -lt 1 ]] ; then >&2 usage; exit 1; fi

# set global defaults
args=""
imgtype=T1

# parse the input arguments
while [[ $# -gt 0 ]] ; do
  case "$1" in
      -t|--type)    imgtype="$2"; shift 2 ;;
      -m|--mm)      mm="$2 $3 $4"; shift 4 ;;
      -v|--vox)     vox="$2 $3 $4"; shift 4 ;;
      -f|--force)   forceflg=TRUE; shift 1 ;;
      -c|--centroid)  centroidflg=TRUE; shift 1 ;;
      *) args=$(echo "$args" "$1"); shift ;; # either obligatory or unknown option
  esac
done

# check if mutually exclusive options have been set
if [[ -n $mm ]] && [[ -n $vox ]] ; then
  >&2 echo ""; >&2 echo "error: either only '-m' or only '-v' can be set."
  usage; exit 1
fi

# set default fov size in mm
[[ -z $mm ]] && mm="128 128 64"

# parse for obligatory arguments
# extract arguments that don't start with "-"
argsobl=$(echo $args | tr " " "\n" | grep -v '^-') || true
# parse obligatory arguments from the non-dash arguments
img=$(echo $argsobl | awk '{print $1}')
base=$(echo $argsobl | awk '{print $2}')

# check if obligatory arguments have been set
if [[ -z $img ]] ; then
  >&2 echo ""; >&2 echo "error: please specify the input image."
  usage; exit 1
fi
[[ -z $base ]] && base="$img"

# remove img and base from list of arguments
args=$(echo $args | tr " " "\n" | grep -v "$img") || true
args=$(echo $args | tr " " "\n" | grep -v "$base") || true

# check if no redundant arguments have been set
if [[ -n $args ]] ; then
  >&2 echo ""; >&2 echo "unsupported arguments are given:" $args
  usage; exit 1
fi

# remove extension
[[ $img =~ / ]] && imgpath="${img%/*}" || imgpath="."
img="${img##*/}"
img=$imgpath/"${img%%.*}"
[[ $base =~ / ]] && basepath="${base%/*}" || basepath="."
base="${base##*/}"
base=$basepath/"${base%%.*}"

# make the output directory
mkdir -p $(dirname $base)

# find the directory of bet_macaque.sh
if [[ -n $MRCATDIR ]] ; then
  scriptdir=$MRCATDIR/core
else
  scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
fi


#==============================
# main code
#==============================

echo "  robust field-of-view cropping of: $img"

# if input and output are the same, save a backup of the input
[[ $img == "$base" ]] && imcp $img ${img}_fullfov

# retrieve dimensions
dims=($(fslval $img dim1) $(fslval $img dim2) $(fslval $img dim3))

# convert mm to vox
if [[ -z $vox ]] ; then
  vox=$(echo $mm $(fslval $img pixdim1) $(fslval $img pixdim2) $(fslval $img pixdim3) | awk '{printf "%d %d %d", $1/$4+0.5, $2/$5+0.5, $3/$6+0.5}')
fi
echo "    desired voxel dimensions: $vox"

# convert to array
maxdims=($vox)

# initialise the fslroi settings
fslroicmd=(0 -1 0 -1 0 -1)
fieldnr=(1 3 5)

# if any of the dimensions exceeds the desired size...
if [[ ${dims[0]} -gt ${maxdims[0]} ]] || [[ ${dims[1]} -gt ${maxdims[1]} ]] || [[ ${dims[2]} -gt ${maxdims[2]} ]] ; then

  # create a tmpdir
  tmpdir=$(mktemp -d "/tmp/bet_macaque.XXXXXXXXXX")
  betbase=$tmpdir/$(basename $base)

  # create a brain mask, deliberately without the frontal and temporal lobe
  # centroids to prevent overfitting of the skull/eyes
  $scriptdir/bet_macaque.sh $img $betbase -t $imgtype -fFP 1 -fTP 1 -n 5

  # retrieve the outer edges and the centroid of the mask
  edges=$(fslstats ${betbase}_brain_mask -w)
  centroid=($(fslstats ${betbase}_brain_mask -C))

  # remove the tmpdir
  rm -rf $tmpdir
fi

# loop over x, y, z
for c in {0..2} ; do

  # if the current dimension is too big, crop it
  if [[ ${dims[$c]} -gt ${maxdims[$c]} ]] ; then

    # retrieve the current dimension of the fov (the brain mask)
    fovmin=$(echo $edges ${fieldnr[$c]} | awk '{print $($9)}')
    fovsize=$(echo $edges ${fieldnr[$c]} | awk '{print $($9+1)}')
    fovmax=$(($fovmin+$fovsize))

    if [[ $forceflg != TRUE ]] && [[ $fovsize -gt $((${maxdims[$c]}-10)) ]] ; then
      # we want at least 5 voxels around the brain mask, even if that means exceeding the desired size
      fovmin=$(($fovmin-5)); [[ $fovmin -lt 0 ]] && fovmin=0
      fovmax=$(($fovmax+5)); [[ $fovmax -gt ${dims[$c]} ]] && fovmax=${dims[$c]}
      fovsize=$(($fovmax-$fovmin))
    else
      # cut the mask to desired size
      if [[ $centroidflg == TRUE ]] ; then
        # cut based on mask centroid
        fovmin=$(echo ${centroid[$c]} ${maxdims[$c]} | awk '{printf "%d", 0.5+$1-($2/2)}')
      else
        # cut based on mask extremes
        fovmin=$(echo $fovmin $fovsize ${maxdims[$c]} | awk '{printf "%d", 0.5+$1-($3-$2)/2}')
      fi
      [[ $fovmin -lt 0 ]] && fovmin=0
      fovsize=${maxdims[$c]}
      fovmax=$(($fovmin+$fovsize))
      [[ $fovmax -gt ${dims[$c]} ]] && fovmin=$((${dims[$c]}-$fovsize))
    fi

    # update the fslroicmd
    fslroicmd[$((${fieldnr[$c]}-1))]=$fovmin
    fslroicmd[${fieldnr[$c]}]=$fovsize
    realisedfov[$c]=$fovsize

  else
    # keep the same size on this dimension
    realisedfov[$c]=${dims[$c]}

  fi
done

# if any of the dimensions of the image exceeded the desired size, crop it
if [[ ${fslroicmd[@]} != "0 -1 0 -1 0 -1" ]] ; then
  echo "    realised voxel dimensions: ${realisedfov[@]}"
  fslroi $img $base ${fslroicmd[@]}
else
  echo "    image already at or below desired field-of-view"
  imrm ${img}_fullfov
fi

echo "    done"
