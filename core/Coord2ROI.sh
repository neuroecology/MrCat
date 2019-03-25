#!/usr/bin/env bash
umask u+rw,g+rw # give group read/write permissions to all new files
set -e    # stop immediately on error


# examples
#sh Coord2ROI.sh --warpmethod=coord --coord=./Oliver/ROIs/TS_coords.txt --dil=5 --refa=F99 --refb=./Oliver/MI00539_proc/f_mean.nii.gz --maskb=refb --closestvox --warpb2a=./Oliver/MI00539_proc/f_mean_to_structural_to_groupavg_2_warp.nii.gz --dir=./Oliver/MI00539_proc/ROI_coord_closest_masked
#sh Coord2ROI.sh --warpmethod=coord --coord=./Oliver/ROIs/TS_coords.txt --dil=5 --refa=F99 --refb=./Oliver/MI00539_proc/f_mean.nii.gz --maskb=refb --warpb2a=./Oliver/MI00539_proc/f_mean_to_structural_to_groupavg_2_warp.nii.gz --dir=./Oliver/MI00539_proc/ROI_coord_masked
#sh Coord2ROI.sh --warpmethod=coord --coord=./Oliver/ROIs/TS_coords.txt --dil=5 --refa=F99 --refb=./Oliver/MI00539_proc/f_mean.nii.gz --warpb2a=./Oliver/MI00539_proc/f_mean_to_structural_to_groupavg_2_warp.nii.gz --dir=./Oliver/MI00539_proc/ROI_coord
#sh Coord2ROI.sh --warpmethod=roi --coord=./Oliver/ROIs/TS_coords.txt --dil=5 --refa=F99 --refb=./Oliver/MI00539_proc/f_mean.nii.gz --maskb=refb --warpa2b=./Oliver/MI00539_proc/groupavg_2_to_structural_to_f_mean_warp.nii.gz --dir=./Oliver/MI00539_proc/ROI_roi
#sh Coord2ROI.sh --warpmethod=none --coord=./Oliver/ROIs/TS_coords.txt --dil=5 --refa=F99 --maska=$MRCATDIR/data/macaque/F99/McLaren_brain_mask --dir=./Oliver/ROI_F99
#sh Coord2ROI.sh --warpmethod=none --coord="10@24@54" --dil=5 --refa=F99 --maska=$MRCATDIR/data/macaque/F99/McLaren_brain_mask --dir=./Oliver/ROI_F99
# minor change to doc for no other reason than to trigger a push

# ------------------------------ #
# Help
# ------------------------------ #

usage() {
cat <<EOF

Coord2ROI.sh: transform a list of coordinates in space 'A' (e.g. in MNI
              space) to ROIs in space 'B' (e.g. functional EPI space). If you do
              not specify a reference image for space 'B', an ROI will be
              created in space 'A' without applying any transformation. At the
              moment only non-linear transformations (warp-fields) are
              supported. You can choose to warp the coordinate and create
              spherical ROIs in space 'B' of a standard size and shape, or to
              create the spherical ROI in space 'A' and warp it to space 'B' to
              allow the ROI to be distorted on a case-by-case basis.

example:
      sh Coord2ROI.sh \
        --warpmethod=coord \
        --coord=coordList.txt \
        --dil=2 \
        --refa=F99 \
        --refb=/my/study/subj/sess/func/func_mean.nii.gz \
        --maskb=/my/study/subj/sess/func/func_brain_mask.nii.gz \
        --warpb2a=func2group_warp.nii.gz \
        --dir=/my/study/subj/sess/func/ROI

usage: $(basename $0)
      obligatory arguments
        --coord=<file>  a text file containing a list of coordinates to expand.
                        Each line contains the [X Y Z] coordinates of one ROI
                        optionally with the ROI name in the fourth position
                        [X Y Z name].
                        Alternatively, you can specify a @-delineated list:
                        X@Y@Z@name
        --dil=<mm>      how many mm to dilate
        --ref=<img>     reference image in target space
                        if would like to warp between a source and target space,
                        please use the options --refa and --refb
      optional arguments
        --refa=<img>    reference image in source space (spaceA)
                        can also be one of 'F99', 'D99', 'MNI', 'SL'
        --refb=<img>    reference image in target space (spaceB)
                        can also be one of 'F99', 'D99', 'MNI', 'SL'
        --warpmethod=X  'none': (default when only one reference is specified)
                        'coord' (default): warp the coordinates from A to B and
                                create the ROI in spaceB
                                this requires B-to-A (inverse) warp-field
                        'roi':  create the ROI in spaceA and warp to spaceB
                                this requires A-to-B (forward) warp-field
        --warpb2a=<img> ANTs/FSL warp-field to go from spaceB to spaceA
                        (for --warpmethod=coord)
        --warpa2b=<img> ANTs/FSL warp-field to go from spaceA to spaceB
                        (for --warpmethod=roi)
        --maska=X       <img>: mask image in spaceA
                        'refa': implicit mask of the reference image in spaceA
                        --maska=X is only used for --warpmethod=roi
        --maskb=X       <img>: mask image in spaceB
                        'refb': implicit mask of the reference image in spaceB
        --closestvox    if the ROI coordinate falls outside the mask, use the
                        closest voxel in the mask (only with --mask*=X)
        --dir=<path>    directory where to store the ROI images
                        default: ROI sub-directory of --refb=<img>

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
    --warpmethod=*) warpMethod="${a#*=}"; shift ;;
    --coord=*)      coordFile="${a#*=}"; shift ;;
    --dil=*)        dilMM="${a#*=}"; shift ;;
    --ref=*)        refBImg="${a#*=}"; shift ;;
    --refa=*)       refAImg="${a#*=}"; shift ;;
    --refb=*)       refBImg="${a#*=}"; shift ;;
    --maska=*)      maskAImg="${a#*=}"; shift ;;
    --maskb=*)      maskBImg="${a#*=}"; shift ;;
    --closestvox)   flgClosestVox=1; shift ;;
    --warpa2b=*)    warpA2B="${a#*=}"; shift ;;
    --warpb2a=*)    warpB2A="${a#*=}"; shift ;;
    --dir=*)        workDir="${a#*=}"; shift ;;
    *)              arg="$arg $a"; shift ;; # ordered arguments
  esac
done

# check if no redundant arguments have been set
if [[ -n $arg ]] ; then >&2 echo ""; >&2 echo "unsupported arguments are given: $arg"; usage; exit 1; fi

# check if obligatory arguments have been set
if [[ -z $coordFile ]] ; then >&2 echo ""; >&2 echo "please provide coordinates with --coord"; usage; exit 1; fi
if [[ -z $dilMM ]] ; then >&2 echo ""; >&2 echo "please specify the dilation radius with --dil"; usage; exit 1; fi


# set defaults for optional arguments
#------------------------------
[[ -z $flgClosestVox ]] && flgClosestVox=0

# test if ANTs ImageMath is present on the path
#------------------------------
flgANTs=$(which ImageMath 2> /dev/null) || true

# remove extensions
#------------------------------
[[ -n $refAImg ]] && refAImg=$(remove_ext $refAImg)
[[ -n $refBImg ]] && refBImg=$(remove_ext $refBImg)
[[ -n $maskAImg ]] && maskAImg=$(remove_ext $maskAImg)
[[ -n $maskBImg ]] && maskBImg=$(remove_ext $maskBImg)
[[ -n $warpA2B ]] && warpA2B=$(remove_ext $warpA2B)
[[ -n $warpB2A ]] && warpB2A=$(remove_ext $warpB2A)

# check reference image properties and set defaults
#------------------------------
# check if at least one reference images is provided, and make sure this is B
[[ -z $refAImg ]] && [[ -z $refBImg ]] && >&2 printf "\nError: Please provide at least one reference image.\n\n" && exit 1
[[ -z $refAImg ]] && [[ -n $refBImg ]] && refAImg="" && maskAImg=""
[[ -n $refAImg ]] && [[ -z $refBImg ]] && refBImg=$refAImg && refAImg="" && maskBImg=$maskAImg && maskAImg=""

# define working directory
#------------------------------
if [[ -z $workDir ]] ; then
  if [[ -n $refBImg ]] && [[ $(imtest $refBImg) -eq 0 ]] ; then
    workDir=$(pwd)/ROI
  else
    workDir=$(dirname $refBImg)/ROI
  fi
fi

# make a ROI directory, with a temporary working directory
mkdir -p $workDir
tmpDir=$(mktemp -d $workDir/tmp.XXXXXXXXXX)


# set method and type of warp
#------------------------------
if [[ -z $warpmethod ]] ; then
  [[ -n $refAImg ]] && [[ -n $refBImg ]] && warpmethod="coord" || warpmethod="none"
fi
case $warpMethod in
  coord ) warpField=$warpB2A; warpFieldOther=$warpA2B ;;
  roi ) warpField=$warpA2B; warpFieldOther=$warpB2A ;;
  * ) warpField=""; warpFieldOther="" ;;
esac
if [[ -z $warpField ]] && [[ -n $warpFieldOther ]] ; then
  warpType=$(fslval $warpFieldOther dim5 | awk '($1==1){print "FSL"}($1>1){print "ANTs"}')
  if [[ $warpType == FSL ]] ; then
    echo "inverting the warpfield"
    echo "to avoid this, please provide the appropriate warpfield (A-to-B or B-to-A), matching --warpmethod=X"
    echo ""
    case $warpMethod in
      coord ) refWarp=$refAImg ;;
      roi ) refWarp=$refBImg ;;
    esac
    warpField=$tmpDir/warp
    invwarp -w $warpFieldOther -o $warpField -r $refWarp
  else
    >&2 printf "\nError: Please provide the appropriate warpfield (A-to-B or B-to-A), matching --warpmethod=X.\n\n" && exit 1
  fi
fi
[[ -n $warpField ]] && warpType=$(fslval $warpField dim5 | awk '($1==1){print "FSL"}($1>1){print "ANTs"}') || warpType=""
[[ -n $warpType ]] && [[ -z $refAImg ]] && >&2 printf "\nError: If you provide a warp-field, please also provide reference images for both spaceA and spaceB.\n\n" && exit 1
[[ -z $warpField ]] || [[ -z $warpType ]] && warpMethod=none

# handle reference and mask images
#------------------------------
# set default reference images
if [[ -n $refAImg ]] && [[ $(imtest $refAImg) -eq 0 ]] ; then
  if [[ $refAImg =~ / ]] || [[ $refAImg =~ . ]] ; then
    >&2 printf "\nError: The reference image does not exist:\n  %s\n\n" "$refAImg" && exit 1
  else
    refAImg=$MRCATDIR/data/macaque/$refAImg/McLaren
  fi
fi
if [[ -n $refBImg ]] && [[ $(imtest $refBImg) -eq 0 ]] ; then
  if [[ $refBImg =~ / ]] || [[ $refBImg =~ . ]] ; then
    >&2 printf "\nError: The reference image does not exist:\n  %s\n\n" "$refBImg" && exit 1
  else
    refBImg=$MRCATDIR/data/macaque/$refBImg/McLaren
  fi
fi


# if requested, use the reference image to create a binary mask
[[ -n $maskAImg ]] && [[ $maskAImg == refa ]] && maskBImg=$refAImg
[[ -n $maskBImg ]] && [[ $maskBImg == refb ]] && maskBImg=$refBImg

# force images to be stored in NIFTI_GZ format
FSLOUTPUTTYPE_ORIG=$FSLOUTPUTTYPE
export FSLOUTPUTTYPE=NIFTI_GZ

# check if they do not exist
for testImg in "$refAImg" "$refBImg" "$maskAImg" "$maskBImg"; do
  if [[ -n $testImg ]] ; then
    [[ $(imtest $testImg) -eq 0 ]] && >&2 printf "\nError: The input image\n  %s\ndoes not exist or is not in a supported format.\n\n" "$testImg" && exit 1
    [[ $(echo $testImg.* | sed "s#$testImg##g") != ".nii.gz" ]] && >&2 printf "\nError: All input images must be in NIFTI_GZ image format (*.nii.gz).\n\n" && exit 1
  fi
done


# ------------------------------ #
# Here be dragons
# ------------------------------ #

# write the coordFile if it does not exist yet
if [[ ! -f $coordFile ]] ; then
  echo ${coordFile//@/ } > $tmpDir/coord.txt
  coordFile="$tmpDir/coord.txt"
fi

# ensure reference images are 3D, take mean over 4D otherwise
[[ -n $refAImg ]] && [[ $(fslval $refAImg dim4) -gt 1 ]] && fslmaths $refAImg -Tmean $tmpDir/refA && refAImg=$tmpDir/refA
[[ -n $refBImg ]] && [[ $(fslval $refBImg dim4) -gt 1 ]] && fslmaths $refBImg -Tmean $tmpDir/refB && refBImg=$tmpDir/refB

# ensure mask image is binarized
[[ -n $maskAImg ]] && fslmaths $maskAImg -bin $tmpDir/maskA && maskAImg=$tmpDir/maskA
[[ -n $maskBImg ]] && fslmaths $maskBImg -bin $tmpDir/maskB && maskBImg=$tmpDir/maskB

# read in the coordinate file one by one
echo "working on:"
while read -r X Y Z roiName ; do

  # skip this line if it is a comment
  [[ $X =~ \# ]] && continue
  # skip this line if it doesn't have [X Y Z] coordinates
  [[ -z $Z ]] && continue

  # create a default name if not provided
  [[ -z $roiName ]] && ((++c)) && roiName=$(printf 'ROI%04d' $c)

  # report on progress
  echo "  $roiName"

  # switch between methods of ROI warping
  case $warpMethod in

    # warp coordinates, then make the ROI in space 'B'
    coord )

      # switch between types of warp field
      case $warpType in
        FSL )
          # use the inverse warp to warp coordinates from A to B
          targetVox=($(echo $X $Y $Z | std2imgcoord -std $refAImg -img $refBImg -warp $warpField -vox -))
          ;;

        ANTs )

          # flip X and Y around zero to match ANTs coordinate system
          Xneg=$(echo $X | awk '{print -1*$1}')
          Yneg=$(echo $Y | awk '{print -1*$1}')

          # write out coordinates in a comma separated file
          cat > $tmpDir/source.csv <<EOF
x,y,z,t,label,mass,volume,count
$Xneg,$Yneg,$Z,0,1,1,1,1
EOF

          # warp points
          antsApplyTransformsToPoints -d 3 -i $tmpDir/source.csv -o $tmpDir/target.csv -t $warpField.nii.gz

          # flip X and Y around zero, store coordinates in variable
          targetCoord=$(awk -F, ' NR == 2 {print -1*$1, -1*$2, $3 }' $tmpDir/target.csv)

          # convert coordinates to voxels, store in array variable
          targetVox=($(echo $targetCoord | std2imgcoord -img $refBImg -std $refBImg -vox -))

          ;;
      esac

      # make a binary ROI at the target voxel
      fslmaths $refBImg -mul 0 -add 1 -roi ${targetVox[0]} 1 ${targetVox[1]} 1 ${targetVox[2]} 1 0 -1 $workDir/$roiName

      # if a mask is specified and the ROI is outside, find the closest voxel inside the mask
      if [[ -n $maskBImg ]] && [[ $flgClosestVox -eq 1 ]] ; then
        if [[ $(fslstats $maskBImg -k $workDir/$roiName -m | awk '{if ($1>0) {print 1} else {print 0}}') -eq 0 ]] ; then
          # calculate distance
          ImageMath 3 $tmpDir/dice DiceAndMinDistSum $maskBImg.nii.gz $workDir/$roiName.nii.gz $tmpDir/dist.nii.gz
          # clean-up
          rm -f $workDir/tmpdice.nii.gz $workDir/tmpmds.nii.gz
          # find voxel with smallest distance
          distMin=$(fslstats $tmpDir/dist.nii.gz -l 0 -R | awk '{print $1}')
          fslmaths $tmpDir/dist -thr $distMin -uthr $distMin -bin $workDir/$roiName
          # give warning if more than 1 voxel was found to be closest
          if [[ $(fslstats $workDir/$roiName -H 2 0.5 1.5 | awk 'NR==2{print int($1)}') -gt 0 ]] ; then
            printf "    Warning: Multiple voxels are equidistant from the ROI coordinate.\n    Your resulting ROI may be bigger than you anticipated.\n"
          fi
        fi
      fi

      # make a spherical ROI around this ROI voxel
      if [[ -n $flgANTs ]] ; then
        # calculate required dilation in voxels
        #dilVox=$(fslval $refBImg pixdim1 | awk 'd='$dilMM'/$1 {printf("%d\n",d+=d<0?-0.5:0.5)}')
        dilVox=$(fslval $refBImg pixdim1 | awk '{print '$dilMM'/$1}')
        # dilate ROI
        ImageMath 3 $workDir/$roiName.nii.gz MD $workDir/$roiName.nii.gz $dilVox
      else
        fslmaths $workDir/$roiName -kernel sphere $dilMM -dilF $workDir/$roiName
      fi

      # apply mask, if requested
      if [[ -n $maskBImg ]] ; then
        fslmaths $workDir/$roiName -mas $maskBImg $workDir/$roiName
      fi

      ;; # end of 'coord' method


    # make the ROI in space 'A', then warp the ROI to space 'B'
    roi )

      # convert coordinates from mm to voxels in space 'A'
      sourceVox=($(echo $X $Y $Z | std2imgcoord -img $refAImg -std $refAImg -vox -))

      # make a binary ROI at the target voxel
      fslmaths $refAImg -mul 0 -add 1 -roi ${sourceVox[0]} 1 ${sourceVox[1]} 1 ${sourceVox[2]} 1 0 -1 $tmpDir/$roiName

      # if a mask is specified and the ROI is outside, find the closest voxel inside the mask
      if [[ -n $maskAImg ]] && [[ $flgClosestVox -eq 1 ]] ; then
        if [[ $(fslstats $maskAImg -k $tmpDir/$roiName -m | awk '{if ($1>0) {print 1} else {print 0}}') -eq 0 ]] ; then
          # calculate distance
          ImageMath 3 $tmpDir/dice DiceAndMinDistSum $maskAImg.nii.gz $tmpDir/$roiName.nii.gz $tmpDir/dist.nii.gz
          # clean-up
          rm -f $workDir/tmpdice.nii.gz $workDir/tmpmds.nii.gz
          # find voxel with smallest distance
          distMin=$(fslstats $tmpDir/dist.nii.gz -l 0 -R | awk '{print $1}')
          fslmaths $tmpDir/dist -thr $distMin -uthr $distMin -bin $tmpDir/$roiName
          # give warning if more than 1 voxel was found to be closest
          if [[ $(fslstats $tmpDir/$roiName -H 2 0.5 1.5 | awk 'NR==2{print int($1)}') -gt 0 ]] ; then
            printf "    Warning: Multiple voxels ate equidistant from the ROI coordinate.\n    Your resulting ROI may be differently shaped than you anticipated.\n"
          fi
        fi
      fi

      # make a spherical ROI around these coordinates
      if [[ -n $flgANTs ]] ; then
        # calculate required dilation in voxels
        #dilVox=$(fslval $refAImg pixdim1 | awk 'd='$dilMM'/$1 {printf("%d\n",d+=d<0?-0.5:0.5)}')
        dilVox=$(fslval $refAImg pixdim1 | awk '{print '$dilMM'/$1}')
        # dilate ROI
        ImageMath 3 $tmpDir/$roiName.nii.gz MD $tmpDir/$roiName.nii.gz $dilVox
      else
        fslmaths $tmpDir/$roiName -kernel sphere $dilMM -dilF $tmpDir/$roiName
      fi

      # mask by supplied mask in space 'A'
      [[ -n $maskAImg ]] && fslmaths $tmpDir/$roiName -mas $maskAImg $tmpDir/$roiName

      # switch between types of warp field
      case $warpType in
        FSL )
          # warp ROI from A to B
          applywarp --rel --interp=nn --in=$tmpDir/$roiName --ref=$refBImg --warp=$warpField --out=$workDir/$roiName
          ;;

        ANTs )
          # warp ROI from A to B
          antsApplyTransforms -d 3 -i $tmpDir/$roiName.nii.gz -r $refBImg.nii.gz -o $workDir/$roiName.nii.gz -n NearestNeighbor -t $warpField.nii.gz -f 0
          ;;

      esac

      # apply mask, if requested
      if [[ -n $maskBImg ]] ; then
        fslmaths $workDir/$roiName -mas $maskBImg $workDir/$roiName
      fi

      ;; # end or 'roi' method


    # just make the ROI based on the coordinates, no warping involved
    * )

      # convert coordinates from mm to voxels
      targetVox=($(echo $X $Y $Z | std2imgcoord -img $refBImg -std $refBImg -vox -))

      # make a spherical ROI around these coordinates
      fslmaths $refBImg -mul 0 -add 1 -roi ${targetVox[0]} 1 ${targetVox[1]} 1 ${targetVox[2]} 1 0 -1 $workDir/$roiName
      if [[ -n $flgANTs ]] ; then
        # calculate required dilation in voxels
        #dilVox=$(fslval $refBImg pixdim1 | awk 'd='$dilMM'/$1 {printf("%d\n",d+=d<0?-0.5:0.5)}')
        dilVox=$(fslval $refBImg pixdim1 | awk '{print '$dilMM'/$1}')
        # dilate ROI
        ImageMath 3 $workDir/$roiName.nii.gz MD $workDir/$roiName.nii.gz $dilVox
      else
        fslmaths $workDir/$roiName -kernel sphere $dilMM -dilF $workDir/$roiName
      fi

      # apply mask, if requested
      if [[ -n $maskBImg ]] ; then
        fslmaths $workDir/$roiName -mas $maskBImg $workDir/$roiName
      fi

      ;;

  esac # warpMethod

done < $coordFile

# clean-up
rm -rf $tmpDir

# reset default file type
FSLOUTPUTTYPE=$FSLOUTPUTTYPE_ORIG
export FSLOUTPUTTYPE

# close report
echo "done"
echo ""
