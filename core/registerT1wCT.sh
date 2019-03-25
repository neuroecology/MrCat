#!/usr/bin/env bash
umask u+rw,g+rw # give group read/write permissions to all new files
set -e    # stop immediately on error

# examples
# sh registerT1wCT.sh --t1w=MNI --t1wmask=MNI_brain_mask --ct=LeetSkull --dir=~/projects/nima/ACCBF/registerT1wCT
# sh registerT1wCT.sh --t1w=MNI --t1wmask=MNI_brain_mask --ct=DrySkull --dir=~/projects/nima/ACCBF/registerT1wCT


# ------------------------------ #
# Help
# ------------------------------ #

usage() {
cat <<EOF

registerT1wCT.sh: register a macaque T1w image to a CT scan. On common
                  application is to register a standard T1w image (say MNI), to
                  a standard CT image (say DrySkull or LeetSkull).

example:
      sh registerT1wCT.sh \
        --t1w=/my/study/subj/T1w/T1w_restore.nii.gz \
        --ct=LeetSkull \
        --dir=/my/study/subj/regCT

usage: $(basename $0)
      obligatory arguments
        --t1w=<img>     path to the T1-weighted image
                        can also be one of 'F99', 'D99', 'MNI', 'SL'
        --ct=<img>      path to the CT image
                        can also be 'CT'
      optional arguments
        --t1wmask=<img> binary mask for the T1w image
                        default: <t1w>_brain_mask
        --dir=<path>    directory where to store the registered images
                        default: './registerT1wCT'

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
    --t1w=*)        T1wImg="${a#*=}"; shift ;;
    --ct=*)         CTImg="${a#*=}"; shift ;;
    --t1wmask=*)    T1wMask="${a#*=}"; shift ;;
    --dir=*)        regDir="${a#*=}"; shift ;;
    *)              arg="$arg $a"; shift ;; # ordered arguments
  esac
done

# check if no redundant arguments have been set
if [[ -n $arg ]] ; then >&2 echo ""; >&2 echo "unsupported arguments are given: $arg"; usage; exit 1; fi

# check if obligatory arguments have been set
if [[ -z $T1wImg ]] ; then >&2 echo ""; >&2 echo "please provide T1w image with --t1w"; usage; exit 1; fi
if [[ -z $CTImg ]] ; then >&2 echo ""; >&2 echo "please specify the CT image with --ct"; usage; exit 1; fi


# handle images and masks
#------------------------------
# remove extension
[[ -n $T1wImg ]] && T1wImg=$(remove_ext $T1wImg)
[[ -n $CTImg ]] && CTImg=$(remove_ext $CTImg)
[[ -n $T1wMask ]] && T1wMask=$(remove_ext $T1wMask)

# set default images
[[ $(imtest $T1wImg) -eq 0 ]] && [[ ! $T1wImg =~ / ]] && T1wImg=$MRCATDIR/data/macaque/${T1wImg//_*/}/$T1wImg
[[ $(imtest $CTImg) -eq 0 ]] && [[ ! $CTImg =~ / ]] && CTImg=$MRCATDIR/data/macaque/CT/${CTImg//_*/}/$CTImg

# set default T1w brain mask
[[ -n $T1wMask ]] && [[ $(imtest $T1wMask) -eq 0 ]] && [[ ! $T1wMask =~ / ]] && T1wMask=$MRCATDIR/data/macaque/${T1wMask//_*/}/$T1wMask
[[ -z $T1wMask ]] && T1wMask=${T1wImg}_brain_mask

# test if images and mask exist
[[ $(imtest $T1wImg) -eq 0 ]] && >&2 printf "\nError: The T1w image does not exist:\n  %s\n\n" "$T1wImg" && exit 1
[[ $(imtest $CTImg) -eq 0 ]] && >&2 printf "\nError: The CT image does not exist:\n  %s\n\n" "$CTImg" && exit 1
[[ $(imtest $T1wMask) -eq 0 ]] && >&2 printf "\nError: The T1w mask does not exist:\n  %s\n\n" "$T1wMask" && exit 1

# extract names
T1w=$(basename $T1wImg)
CT=$(basename $CTImg)

# force images to be stored in NIFTI_GZ format
FSLOUTPUTTYPE_ORIG=$FSLOUTPUTTYPE
export FSLOUTPUTTYPE=NIFTI_GZ


# define working directory
#------------------------------
# ensure the registration directory exists
if [[ -z $regDir ]] ; then
  regDir=$(pwd)/registerT1wCT
else
  regDir=${regDir//\~/$HOME}
fi
mkdir -p $regDir

# make a temporary working directory
workDir=$(mktemp -d $regDir/tmp.XXXXXXXXXX)


# initialise the T1w and CT images
#------------------------------
echo "initialising images"

# copy the T1w image
imcp $T1wImg $workDir/$T1w
imcp $T1wMask $workDir/${T1w}_brain_mask

# copy the CT image and assign default orientation labels
imcp $CTImg $workDir/$CT
fslorient -deleteorient $workDir/$CT
fslorient -setqformcode 1 $workDir/$CT
fslorient -forceradiological $workDir/$CT

# retrieve the voxel size (in micrometers)
voxSizeT1w=$(fslval $workDir/$T1w pixdim1 | awk 'x=$1*1000{printf("%d\n",x+=x<0?-0.5:0.5)}')
voxSizeCT=$(fslval $workDir/$CT pixdim1 | awk 'x=$1*1000{printf("%d\n",x+=x<0?-0.5:0.5)}')

# pad the T1w image by 10mm at resolution for CT resampling later on
voxSizeHighRes=$(echo $voxSizeT1w $voxSizeCT | awk '{x=$1<$2?$1:$2; print x/1000}')
voxPad=$(echo $voxSizeHighRes | awk 'x=15/$1{printf("%d\n",x+=x<0?-0.5:0.5)}')
# if the CT image has a higher resolution, resample the T1w before padding
if [[ $voxSizeCT -lt $voxSizeT1w ]] ; then
  ResampleImageBySpacing 3 $workDir/${T1w}.nii.gz $workDir/${T1w}_pad.nii.gz $voxSizeHighRes $voxSizeHighRes $voxSizeHighRes 0 > /dev/null
  ImageMath 3 $workDir/${T1w}_pad.nii.gz PadImage $workDir/${T1w}_pad.nii.gz $voxPad
else
  ImageMath 3 $workDir/${T1w}_pad.nii.gz PadImage $workDir/${T1w}.nii.gz $voxPad
fi

# create versions of the images at different resolutions
ResampleImageBySpacing 3 $workDir/${T1w}.nii.gz $workDir/${T1w}_0mm5.nii.gz 0.5 0.5 0.5 0 > /dev/null
ResampleImageBySpacing 3 $workDir/${T1w}_brain_mask.nii.gz $workDir/${T1w}_0mm5_brain_mask.nii.gz 0.5 0.5 0.5 0 0 1 > /dev/null

# also for CT image
ResampleImageBySpacing 3 $workDir/${CT}.nii.gz $workDir/${CT}_0mm5.nii.gz 0.5 0.5 0.5 0 > /dev/null
ResampleImageBySpacing 3 $workDir/${CT}.nii.gz $workDir/${CT}_1mm.nii.gz 1 1 1 0 > /dev/null

# from here on, most of the work will be done on the 0.5mm resolution for computational efficiency

# retrieve the image dimensions
xSize=$(fslval $workDir/${T1w}_0mm5 dim1)
ySize=$(fslval $workDir/${T1w}_0mm5 dim2)
zSize=$(fslval $workDir/${T1w}_0mm5 dim3)

# find the midline of the brain
xMidVox=$(fslstats $workDir/${T1w}_0mm5_brain_mask -C | awk '{printf("%d\n",$1+=$0<0?-0.5:0.5)}') # in vox

# scale the 0.5mm T1w image
valMax=$(fslstats $workDir/${T1w}_0mm5 -R | awk '{print $2}')
fslmaths $workDir/${T1w}_0mm5 -thr 0 -div $valMax $workDir/${T1w}_0mm5


# make a T1w head mask
#------------------------------
echo "making a mask of the head in T1w space"

# dilate the brain mask, especially inferiorly
ImageMath 3 $workDir/${T1w}_0mm5_brain_mask_dil.nii.gz MD $workDir/${T1w}_0mm5_brain_mask.nii.gz 10
yDil=8
fslroi $workDir/${T1w}_0mm5_brain_mask_dil $workDir/kernel 0 1 0 1 0 $((yDil*2+1))
fslmaths $workDir/kernel -mul 0 -add 1 -roi 0 -1 0 -1 $yDil -1 0 -1 $workDir/kernel
fslmaths $workDir/${T1w}_0mm5_brain_mask_dil -kernel file $workDir/kernel -dilF $workDir/${T1w}_0mm5_brain_mask_dil_inf
imrm $workDir/kernel

# make a 'head' mask
fslmaths $workDir/${T1w}_0mm5 -thr 0.3 -add $workDir/${T1w}_0mm5_brain_mask_dil_inf -bin $workDir/${T1w}_0mm5_head_mask
ImageMath 3 $workDir/${T1w}_0mm5_head_mask.nii.gz FillHoles $workDir/${T1w}_0mm5_head_mask.nii.gz 1

# dilate the mask towards the midline
xDil=10
# dilate leftwards (but restrict to the right hemisphere)
fslroi $workDir/${T1w}_0mm5_head_mask $workDir/kernel 0 $((xDil*2+1)) 0 1 0 1
fslmaths $workDir/kernel -mul 0 -add 1 -roi 0 $((xDil+1)) 0 -1 0 -1 0 -1 $workDir/kernel
fslmaths $workDir/${T1w}_0mm5_head_mask -kernel file $workDir/kernel -dilF -roi 0 $((xMidVox+1)) 0 -1 0 -1 0 -1 $workDir/${T1w}_0mm5_head_mask_left
# dilate rightwards (but restrict to the left hemisphere)
fslroi $workDir/${T1w}_0mm5_head_mask $workDir/kernel 0 $((xDil*2+1)) 0 1 0 1
fslmaths $workDir/kernel -mul 0 -add 1 -roi $xDil -1 0 -1 0 -1 0 -1 $workDir/kernel
fslmaths $workDir/${T1w}_0mm5_head_mask -kernel file $workDir/kernel -dilF -roi $xMidVox -1 0 -1 0 -1 0 -1 $workDir/${T1w}_0mm5_head_mask_right
# combine the leftward and rightward dilations
fslmaths $workDir/${T1w}_0mm5_head_mask -add $workDir/${T1w}_0mm5_head_mask_left -add $workDir/${T1w}_0mm5_head_mask_right -bin $workDir/${T1w}_0mm5_head_mask
imrm $workDir/kernel $workDir/${T1w}_0mm5_head_mask_left $workDir/${T1w}_0mm5_head_mask_right

# polish the head mask
ImageMath 3 $workDir/${T1w}_0mm5_head_mask.nii.gz GetLargestComponent $workDir/${T1w}_0mm5_head_mask.nii.gz
ImageMath 3 $workDir/${T1w}_0mm5_head_mask.nii.gz FillHoles $workDir/${T1w}_0mm5_head_mask.nii.gz 2
# remove outer slices
fslmaths $workDir/${T1w}_0mm5_head_mask -roi 1 $((xSize-2)) 1 $((ySize-2)) 1 $((zSize-2)) 0 -1 $workDir/${T1w}_0mm5_head_mask
# alternate dilation and erosion with a gaussion kernel for a smooth result
ImageMath 3 $workDir/${T1w}_0mm5_head_mask.nii.gz G $workDir/${T1w}_0mm5_head_mask.nii.gz 1.5
ThresholdImage 3 $workDir/${T1w}_0mm5_head_mask.nii.gz $workDir/${T1w}_0mm5_head_mask.nii.gz 0.4 inf 1 0
ImageMath 3 $workDir/${T1w}_0mm5_head_mask.nii.gz G $workDir/${T1w}_0mm5_head_mask.nii.gz 1.5
ThresholdImage 3 $workDir/${T1w}_0mm5_head_mask.nii.gz $workDir/${T1w}_0mm5_head_mask.nii.gz 0.6 inf 1 0
# ensure the dilated brain mask in included
fslmaths $workDir/${T1w}_0mm5_head_mask -add $workDir/${T1w}_0mm5_brain_mask_dil -bin $workDir/${T1w}_0mm5_head_mask


# make a T1w skull mask
#------------------------------
echo "making a mask of the skull in T1w space"

# erode to get a preliminary skull mask
ImageMath 3 $workDir/${T1w}_0mm5_skull_mask.nii.gz ME $workDir/${T1w}_0mm5_head_mask.nii.gz 5
# remove outer slices
fslmaths $workDir/${T1w}_0mm5_skull_mask -roi 1 $((xSize-2)) 1 $((ySize-2)) 1 $((zSize-2)) 0 -1 $workDir/${T1w}_0mm5_skull_mask

# fix the corrupted header after ANTs (reset slice thickness)
fslcpgeom $workDir/${T1w}_0mm5_brain_mask $workDir/${T1w}_0mm5_head_mask
fslcpgeom $workDir/${T1w}_0mm5_brain_mask $workDir/${T1w}_0mm5_skull_mask

# extract skull: invert contrast or T1w, mask by head, and remove the brain
fslmaths $workDir/${T1w}_0mm5 -mul -1 -add 1 -mas $workDir/${T1w}_0mm5_skull_mask -sub $workDir/${T1w}_0mm5_brain_mask -thr 0.7 -uthr 0.9999999 $workDir/${T1w}_0mm5_fakeCT
fslmaths $workDir/${T1w}_0mm5_fakeCT -bin $workDir/${T1w}_0mm5_skull_mask

# keep only the main continuous segment of the skull
ImageMath 3 $workDir/${T1w}_0mm5_skull_mask.nii.gz GetLargestComponent $workDir/${T1w}_0mm5_skull_mask.nii.gz
fslmaths $workDir/${T1w}_0mm5_fakeCT -mas $workDir/${T1w}_0mm5_skull_mask $workDir/${T1w}_0mm5_fakeCT


# defining the skull cavity in the CT image
#------------------------------
echo "defining skull cavity in CT image"

# determine dilation based on name of CT
case $CT in
  LeetSkull ) dilVox=13 ;;
  * ) dilVox=7 ;;
esac

# fill holes in the CT image and dilate
fslmaths $workDir/${CT}_0mm5 -bin $workDir/${CT}_0mm5_filled
ImageMath 3 $workDir/${CT}_0mm5_filled.nii.gz FillHoles $workDir/${CT}_0mm5_filled.nii.gz 0.9
ImageMath 3 $workDir/${CT}_0mm5_filled_dil.nii.gz MD $workDir/${CT}_0mm5_filled.nii.gz $dilVox

# find the brain cavity (in eroded form)
fslmaths $workDir/${CT}_0mm5_filled_dil -binv $workDir/${CT}_0mm5_brain_mask_ero
cluster --in=$workDir/${CT}_0mm5_brain_mask_ero --thresh=0.5 --oindex=$workDir/${CT}_0mm5_brain_mask_ero --minextent=20000 --no_table
fslmaths $workDir/${CT}_0mm5_brain_mask_ero -uthr 1 $workDir/${CT}_0mm5_brain_mask_ero

# expand to fill the full cavity
case $CT in
  LeetSkull )
    # dilate
    ImageMath 3 $workDir/${CT}_0mm5_brain_mask.nii.gz MD $workDir/${CT}_0mm5_brain_mask_ero.nii.gz $((dilVox+9))
    # cut of the top part
    topVox=$(fslstats $workDir/${CT}_0mm5_brain_mask -w | awk '{print $6 - $5}')
    fslmaths $workDir/${CT}_0mm5_brain_mask -roi 0 -1 0 -1 0 $((topVox-16)) 0 -1 $workDir/${CT}_0mm5_brain_mask
    # remove skull, etc
    fslmaths $workDir/${CT}_0mm5_brain_mask -sub $workDir/${CT}_0mm5_filled -bin $workDir/${CT}_0mm5_brain_mask
    # erode once
    ImageMath 3 $workDir/${CT}_0mm5_brain_mask.nii.gz ME $workDir/${CT}_0mm5_brain_mask.nii.gz 2
    # keep only the largest chunk
    ImageMath 3 $workDir/${CT}_0mm5_brain_mask.nii.gz GetLargestComponent $workDir/${CT}_0mm5_brain_mask.nii.gz
    # smooth out
    ImageMath 3 $workDir/${CT}_0mm5_brain_mask.nii.gz G $workDir/${CT}_0mm5_brain_mask.nii.gz 1.5
    ThresholdImage 3 $workDir/${CT}_0mm5_brain_mask.nii.gz $workDir/${CT}_0mm5_brain_mask.nii.gz 0.4 inf 1 0
    ;;
  * )
    ImageMath 3 $workDir/${CT}_0mm5_brain_mask.nii.gz MD $workDir/${CT}_0mm5_brain_mask_ero.nii.gz $dilVox
    fslmaths $workDir/${CT}_0mm5_brain_mask -sub $workDir/${CT}_0mm5_filled -bin $workDir/${CT}_0mm5_brain_mask
    ;;
esac


# preparing and initialising registration
#------------------------------
echo "initialising registration"

# determine initialisation based on name of CT
case $CT in
  LeetSkull )
    # down-sample the brain masks to initialise the registration
    ResampleImageBySpacing 3 $workDir/${T1w}_0mm5_brain_mask.nii.gz $workDir/${T1w}_init.nii.gz 1.5 1.5 1.5 0 > /dev/null
    ResampleImageBySpacing 3 $workDir/${CT}_0mm5_brain_mask.nii.gz $workDir/${CT}_init.nii.gz 1.5 1.5 1.5 0 > /dev/null
    ;;
  * )
    # smooth and down-sample the brain masks to initialise the registration
    ResampleImageBySpacing 3 $workDir/${T1w}_0mm5_brain_mask.nii.gz $workDir/${T1w}_init.nii.gz 1.5 1.5 1.5 1 > /dev/null
    ResampleImageBySpacing 3 $workDir/${CT}_0mm5_brain_mask.nii.gz $workDir/${CT}_init.nii.gz 1.5 1.5 1.5 1 > /dev/null
    fslmaths $workDir/${T1w}_init -thr 0 $workDir/${T1w}_init
    fslmaths $workDir/${CT}_init -thr 0 $workDir/${CT}_init
    ;;
esac




# one could consider to improve the registration by also considering the spatial
# derivative of the images to improve the registration of borders to do so:
# calculate Laplace derivative over the whole image
#ImageMath 3 $workDir/${T1w}_laplace.nii.gz Laplacian $workDir/${T1w}_lowres.nii.gz 1.5 1
#ImageMath 3 $workDir/${CT}_laplace.nii.gz Laplacian $workDir/${CT}_filled.nii.gz 1.5 1
#ResampleImageBySpacing 3 $workDir/${T1w}_laplace.nii.gz $workDir/${T1w}_init.nii.gz 1.5 1.5 1.5 1
#ResampleImageBySpacing 3 $workDir/${CT}_laplace.nii.gz $workDir/${CT}_init.nii.gz 1.5 1.5 1.5 1

# initialise the registration based on the brain mask/cavity
antsAI \
  --dimensionality 3 \
  --output $workDir/CT2T1w_init.mat \
  --transform Rigid[0.1] \
  --metric MI[$workDir/${T1w}_init.nii.gz,$workDir/${CT}_init.nii.gz,32,Regular,0.1] \
  --search-factor [5,0.3] \
  --align-principal-axes 0 \
  --convergence [10,1e-6] \
  --verbose 1


# registration of the skull cavity
#------------------------------
echo "register the skull cavity (rigid + affine)"

# run an affine registration on the brain masks
antsRegistration \
  --dimensionality 3 \
  --output $workDir/CT2T1w_ \
  --winsorize-image-intensities [0.005,0.995] \
  --use-histogram-matching 0 \
  --initial-moving-transform $workDir/CT2T1w_init.mat \
  --transform Rigid[0.1] \
  --metric MI[$workDir/${T1w}_0mm5_brain_mask.nii.gz,$workDir/${CT}_0mm5_brain_mask.nii.gz,1,32,Regular,0.1] \
  --convergence [500x250x100,1e-6,10] \
  --shrink-factors 4x2x1 \
  --smoothing-sigmas 2x1x0vox \
  --transform Affine[0.1] \
  --metric MI[$workDir/${T1w}_0mm5_brain_mask.nii.gz,$workDir/${CT}_0mm5_brain_mask.nii.gz,1,32,Regular,0.1] \
  --convergence [500x250x100,1e-6,10] \
  --shrink-factors 4x2x1 \
  --smoothing-sigmas 2x1x0vox \
  --float \
  --verbose 1


# registration of the skull itself
#------------------------------
echo "register the skull (rigid + affine + non-linear)"

# non-linear registration based on skull masks
antsRegistration \
  --dimensionality 3 \
  --output $workDir/CT2T1w_ \
  --use-histogram-matching 0 \
  --winsorize-image-intensities [0.005,0.995] \
  --initial-moving-transform $workDir/CT2T1w_0GenericAffine.mat \
  --transform Affine[0.1] \
  --metric MI[$workDir/${T1w}_0mm5_skull_mask.nii.gz,$workDir/${CT}_0mm5_filled.nii.gz,1,32,Regular,0.1] \
  --convergence [500x250x100,1e-6,10] \
  --shrink-factors 4x2x1 \
  --smoothing-sigmas 2x1x0vox \
  --transform BSplineSyN[0.1,5,0,3] \
  --metric MI[$workDir/${T1w}_0mm5_skull_mask.nii.gz,$workDir/${CT}_0mm5_filled.nii.gz,1,32,Regular,0.1] \
  --convergence [50,1e-6,10] \
  --shrink-factors 1 \
  --smoothing-sigmas 0vox \
  --float \
  --verbose 1


# resampling of the T1w and CT images
#------------------------------
echo "resampling of CT in T1w space and vice versa"

# create a mask of the CT image
fslmaths $workDir/${CT} -bin $workDir/${CT}_mask

# resample CT mask to T1w space
antsApplyTransforms \
  --dimensionality 3 \
  --input $workDir/${CT}_mask.nii.gz \
  --reference-image $workDir/${T1w}_pad.nii.gz \
  --output $workDir/${CT}_mask_nonlinear.nii.gz \
  --interpolation NearestNeighbor \
  --transform [$workDir/CT2T1w_1Warp.nii.gz] \
  --transform [$workDir/CT2T1w_0GenericAffine.mat] \
  --default-value 0 \
  --float

# resample CT to T1w space
antsApplyTransforms \
  --dimensionality 3 \
  --input $workDir/${CT}.nii.gz \
  --reference-image $workDir/${T1w}_pad.nii.gz \
  --output $workDir/${CT}_nonlinear.nii.gz \
  --interpolation BSpline[3] \
  --transform [$workDir/CT2T1w_1Warp.nii.gz] \
  --transform [$workDir/CT2T1w_0GenericAffine.mat] \
  --default-value 0 \
  --float

# mask the resampled CT image by its resampled mask
fslmaths $workDir/${CT}_nonlinear -mas $workDir/${CT}_mask_nonlinear -thr 0 $workDir/${CT}_nonlinear
# truncate extremely high intensity values
ImageMath 3 $workDir/${CT}_nonlinear.nii.gz TruncateImageIntensity $workDir/${CT}_nonlinear.nii.gz -1 0.9999

# resample T1w to CT according to non-linear transform
antsApplyTransforms \
  --dimensionality 3 \
  --input $workDir/${T1w}.nii.gz \
  --reference-image $workDir/${CT}.nii.gz \
  --output $workDir/${T1w}_nonlinear.nii.gz \
  --interpolation BSpline[3] \
  --transform [$workDir/CT2T1w_0GenericAffine.mat,1] \
  --transform [$workDir/CT2T1w_1InverseWarp.nii.gz] \
  --default-value 0 \
  --float

# copy the final images and transformations
mkdir -p $regDir/${T1w}
mv $workDir/${T1w}_pad.nii.gz $regDir/${T1w}/${T1w}_pad${CT}.nii.gz
mv $workDir/${CT}_nonlinear.nii.gz $regDir/${T1w}/${CT}.nii.gz

mkdir -p $regDir/${CT}
mv $workDir/${CT}.nii.gz $regDir/${CT}/${CT}.nii.gz
mv $workDir/${T1w}_nonlinear.nii.gz $regDir/${CT}/${T1w}.nii.gz

mkdir -p $regDir/transform
mv $workDir/CT2T1w_0GenericAffine.mat $regDir/transform/${CT}_to_${T1w}_0GenericAffine.mat
mv $workDir/CT2T1w_1Warp.nii.gz $regDir/transform/${CT}_to_${T1w}_1Warp.nii.gz
mv $workDir/CT2T1w_1InverseWarp.nii.gz $regDir/transform/${CT}_to_${T1w}_1InverseWarp.nii.gz


# if this is the LeetSkull image, take the original Leet image along as well
if [[ $CT == LeetSkull ]] ; then

  # create a mask of the Leet image
  ThresholdImage 3 $MRCATDIR/data/macaque/CT/Leet/Leet.nii.gz $workDir/Leet_mask.nii.gz 1030.6 2999.9 1 0

  # resample Leet mask to T1w space
  antsApplyTransforms \
    --dimensionality 3 \
    --input $workDir/Leet_mask.nii.gz \
    --reference-image $workDir/${T1w}_pad.nii.gz \
    --output $workDir/Leet_mask_nonlinear.nii.gz \
    --interpolation NearestNeighbor \
    --transform [$workDir/CT2T1w_1Warp.nii.gz] \
    --transform [$workDir/CT2T1w_0GenericAffine.mat] \
    --default-value 0 \
    --float

  # resample Leet to T1w space, once linear, once BSpline
  antsApplyTransforms \
    --dimensionality 3 \
    --input $MRCATDIR/data/macaque/CT/Leet/Leet.nii.gz \
    --reference-image $workDir/${T1w}_pad.nii.gz \
    --output $workDir/Leet_nonlinear_Trilinear.nii.gz \
    --interpolation Linear \
    --transform [$workDir/CT2T1w_1Warp.nii.gz] \
    --transform [$workDir/CT2T1w_0GenericAffine.mat] \
    --default-value 0 \
    --float

  antsApplyTransforms \
    --dimensionality 3 \
    --input $MRCATDIR/data/macaque/CT/Leet/Leet.nii.gz \
    --reference-image $workDir/${T1w}_pad.nii.gz \
    --output $workDir/Leet_nonlinear_BSpline.nii.gz \
    --interpolation BSpline[3] \
    --transform [$workDir/CT2T1w_1Warp.nii.gz] \
    --transform [$workDir/CT2T1w_0GenericAffine.mat] \
    --default-value 0 \
    --float

  # combine the linear and BSpline parts
  MultiplyImages 3 $workDir/Leet_nonlinear_BSpline.nii.gz $workDir/Leet_mask_nonlinear.nii.gz $workDir/Leet_nonlinear_BSpline.nii.gz
  ImageMath 3 $workDir/Leet_nonlinear.nii.gz overadd $workDir/Leet_nonlinear_Trilinear.nii.gz $workDir/Leet_nonlinear_BSpline.nii.gz

  # copy the final image
  mv $workDir/Leet_nonlinear.nii.gz $regDir/${T1w}/Leet.nii.gz

fi


# all done
#------------------------------

# clean-up
rm -rf $workDir

# close report
echo "done"
echo ""
