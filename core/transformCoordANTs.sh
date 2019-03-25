#!/usr/bin/env bash
umask u+rw,g+rw # give group read/write permissions to all new files
set -e    # stop immediately on error

# examples
# sh transformCoordANTs.sh --coord=0,2,19 --transform=/Users/you/projects/thisProject/registerT1wCT/transform/LeetSkull_to_MNI_0GenericAffine.mat
# sh transformCoordANTs.sh --coord=0,2,19 --transform=/Users/you/projects/thisProject/registerT1wCT/transform/LeetSkull_to_MNI_0GenericAffine.mat --vox --ref=$MRCATDIR/data/macaque/CT/Leet/LeetSkull.nii.gz
# sh transformCoordANTs.sh --coord=0,2,19 --transform=/Users/you/projects/thisProject/registerT1wCT/transform/LeetSkull_to_MNI_1Warp.nii.gz --transform=/Users/you/projects/thisProject/registerT1wCT/transform/LeetSkull_to_MNI_0GenericAffine.mat --vox --ref=$MRCATDIR/data/macaque/CT/Leet/LeetSkull.nii.gz
# sh transformCoordANTs.sh --coord=54.3561,35.8973,54.5032 --transform=[/Users/you/projects/thisProject/registerT1wCT/transform/LeetSkull_to_MNI_0GenericAffine.mat,1] --transform=/Users/you/projects/thisProject/registerT1wCT/transform/LeetSkull_to_MNI_1InverseWarp.nii.gz




# ------------------------------ #
# Help
# ------------------------------ #

usage() {
cat <<EOF

transformCoordANTs.sh: wrapper around antsApplyTransformsToPoints to accomodate
                       the LPS coordinate system and the obligatory csv input
                       file. Can also output in voxel space. For details on the
                       transforms and how to specify them, check
                       antsApplyTransformsToPoints itself.

example:
      sh transformCoordANTs.sh \
        --coord=1,2,3 \
        --transform=[./A2B_0GenericAffine.mat,1] \
        --transform=./A2B_1InverseWarp.nii.gz

usage: $(basename $0)
      obligatory arguments
        --coord=X,Y,Z   comma-separated list of coordinates
        --transform=X   any transform supported by ANTs can be entered here.
                        Multiple transformations (affine, non-linear) can be
                        specified by repeating the --transform=X argument
      optional arguments
        --vox           output will be given in voxels of --ref=<img>
        --swapdim=X     swap the dimensions/axes of the output voxel coordinates
                        for example: x,y,z or -y,x,z
        --ref=<img>     a reference image matching the target space

EOF
}


# ------------------------------ #
# Housekeeping
# ------------------------------ #

# if no arguments given, or help is requested, return the usage
if [[ $# -eq 0 ]] || [[ $@ =~ --help ]] ; then usage; exit 0; fi
# if too few arguments given, return the usage, exit with error
if [[ $# -lt 2 ]] ; then >&2 usage; exit 1; fi


# parse the input arguments
#------------------------------
transformCmd=""
for a in "$@" ; do
  case $a in
    --coord=*)      coordSource="${a#*=}"; shift ;;
    --transform=*)  transformCmd+="-t ${a#*=} "; shift ;;
    --vox)          outputVox=1; shift ;;
    --swapdim=*)    outputAxes="${a#*=}"; shift ;;
    --ref=*)        refTarget="${a#*=}"; shift ;;
    *)              arg="$arg $a"; shift ;; # ordered arguments
  esac
done

# check if no redundant arguments have been set
if [[ -n $arg ]] ; then >&2 echo ""; >&2 echo "unsupported arguments are given: $arg"; usage; exit 1; fi

# check if obligatory arguments have been set
if [[ -z $coordSource ]] ; then >&2 echo ""; >&2 echo "please provide X,Y,Z coordinates with --coord"; usage; exit 1; fi
if [[ -z $transformCmd ]] ; then >&2 echo ""; >&2 echo "please specify at least one transform with --transform"; usage; exit 1; fi


# set defaults for optional arguments
#------------------------------
[[ -z $outputVox ]] && outputVox=0
[[ -z $outputAxes ]] && outputAxes=x,y,z
[[ $outputVox -eq 0 ]] && refTarget="" && outputAxes=""

# test if reference image exists
[[ $outputVox -eq 1 ]] && [[ $(imtest $refTarget) -eq 0 ]] && >&2 printf "\nError: The target reference image does not exist:\n  %s\n\n" "$refTarget" && exit 1


# here be dragons
#------------------------------

# extract source coordinates
X=$(echo $coordSource | cut -d, -f1)
Y=$(echo $coordSource | cut -d, -f2)
Z=$(echo $coordSource | cut -d, -f3)

# flip X and Y around zero go from the RAS to the LPS coordinate system (used by ANTs)
Xneg=$(echo $X | awk '{print -1*$1}')
Yneg=$(echo $Y | awk '{print -1*$1}')

# make a temporary working directory
workDir=$(mktemp -d /tmp/tmp.transformCoordANTs.XXXXXXXXXX)

# write out coordinates in a comma separated file
cat > $workDir/coordSource.csv <<EOF
x,y,z,t,label,mass,volume,count
$Xneg,$Yneg,$Z,0,1,1,1,1
EOF

# warp points
antsApplyTransformsToPoints -d 3 -i $workDir/coordSource.csv -o $workDir/coordTarget.csv $transformCmd

# flip X and Y around zero, store coordinates in variable
targetCoord=$(awk -F, ' NR == 2 {print -1*$1, -1*$2, $3 }' $workDir/coordTarget.csv)

# if requested, convert coordinates to voxels
if [[ $outputVox -eq 1 ]] ; then
  targetCoord=$(echo $targetCoord | std2imgcoord -img $refTarget -std $refTarget -vox -)

  # swap the dimensions, if requested
  if [[ -n $outputAxes ]] ; then
    # loop over requested axes
    t=""
    for a in ${outputAxes//,/ } ; do
      case $a in
        x ) t+=$(echo $targetCoord | awk '{print $1}') ;;
        -x ) t+=$(echo $targetCoord "$(fslval $refTarget dim1)" | awk '{print $4-$1}') ;;
        y ) t+=$(echo $targetCoord | awk '{print $2}') ;;
        -y ) t+=$(echo $targetCoord "$(fslval $refTarget dim2)" | awk '{print $4-$2}') ;;
        z ) t+=$(echo $targetCoord | awk '{print $3}') ;;
        -z ) t+=$(echo $targetCoord "$(fslval $refTarget dim3)" | awk '{print $4-$3}') ;;
        * ) >&2 echo "unknown axis specified in --swapdim"; usage; exit 1 ;;
      esac
      t+=" "
    done
    targetCoord=$t
  fi

fi

# report
echo $targetCoord

# clean-up
rm -rf $workDir
