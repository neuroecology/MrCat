#!/usr/bin/env bash
set -e    # stop immediately on error
umask u+rw,g+rw # give group read/write permissions to all new files

# rsn_vol2surf.sh


# ------------------------------ #
# Help
# ------------------------------ #

usage() {
cat <<EOF

rsn_vol2surf.sh: Project volumetric functional timeseries to cortical surface

example:
      sh rsn_vol2surf.sh --funcimg=func

usage: $(basename $0)
      obligatory arguments
        [--funcimg=<image>] : functional time series
      optional arguments
        [--funcbase=<string>] : basename of the functional image
        [--structimg=<image>] : structural T1w image
        [--structbase=<string>] : basename of the structural image
        [--transdir=<directory>] : transformation directory
        [--projmethod=<trilinear/myelin>] : vol2surf projection method (default: trilinear)
        [--surfname=X] : name of the surface to be padded in the file names
        [--surfleft=X] : left surface
        [--surfright=X] : right surface
        [--volspace]=X] : [ F99 (default), func ] space to represent the volume in

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
projMethod="trilinear"
surfName="F99_10k"
surfLeft=$MRCATDIR/data/macaque/F99/surf/left.fiducial.$surfName.surf.gii
surfRight=$MRCATDIR/data/macaque/F99/surf/right.fiducial.$surfName.surf.gii

# parse the input arguments
for a in "$@" ; do
  case $a in
    -i=*|--funcimg=*)     funcImg="${a#*=}"; shift ;;
    -b=*|--funcbase=*)    funcBase="${a#*=}"; shift ;;
    -s=*|--structimg=*)   structImg="${a#*=}"; shift ;;
    -z=*|--structbase=*)  structBase="${a#*=}"; shift ;;
    -t=*|--transdir=*)    transDir="${a#*=}"; shift ;;
    -p=*|--projmethod=*)  projMethod="${a#*=}"; shift ;;
    -n=*|--surfname=*)    surfName="${a#*=}"; shift ;;
    -l=*|--surfleft=*)    surfLeft="${a#*=}"; shift ;;
    -r=*|--surfright=*)   surfRight="${a#*=}"; shift ;;
    -v=*|--volspace=*)    volSpace="${a#*=}"; shift ;;
    #-o=*|--option=*)     option="${a#*=}"; shift ;;
    *)                    arg="$arg $a"; shift ;; # ordered arguments
  esac
done

# check if obligatory arguments have been set
if [[ -z $funcImg ]] ; then
  >&2 echo ""; >&2 echo "error: please specify the input image."
  usage; exit 1
fi

# check if no redundant arguments have been set
if [[ -n $arg ]] ; then
  >&2 echo ""; >&2 echo "unsupported arguments are given:" $arg
  usage; exit 1
fi

# infer or set the functional directory and image
funcImg=$(remove_ext $funcImg)
funcDir=$(dirname $funcImg)
[[ -z $funcBase ]] && funcBase=$(basename $funcImg)
#funcPad=$(echo $(basename $funcImg) | sed s#^$funcBase##g)
funcBaseProc=$(basename $funcImg)

# infer or set the structural directory and image
[[ -z $structImg ]] && structDir=$(cd $funcDir/../structural; pwd) && structImg=$structDir/struct
structImg=$(remove_ext $structImg)
structDir=$(dirname $structImg)
[[ -z $structBase ]] && structBase=$(basename $structImg)

# set the default volumetric subcortical space
[[ -z $volSpace ]] && volSpace=F99

# set the transformation directory if not explicitely specified
if [[ -z $transDir ]] ; then
  runIdx=$(echo ${funcImg##*/} | grep -oh "run[1-9]" | cut -d"n" -f2)
  if [[ -z $runIdx ]] ; then
    # when only a single run is found (without a run index),
    # store the transforms at the same level as the functional directory
    transDir=$(cd $funcDir/../transform; pwd)
  else
    # store the transforms under the functional run directory
    transDir=$funcDir/transform
  fi
fi


# ------------------------------ #
# Do the work
# ------------------------------ #

#=========================================
# Data into standard space
#=========================================

echo "Warping F99 surface to functional"

# combine affine and warp to get ${funcBase}_to_F99 and F99_to_${funcBase}
if [[ ! -r $transDir/${funcBase}_to_F99_warp.nii.gz ]] ; then
  convertwarp --ref=$MRCATDIR/data/macaque/F99/McLaren --premat=$transDir/${funcBase}_to_${structBase}.mat --warp1=$structDir/../transform/${structBase}_to_F99_warp --out=$transDir/${funcBase}_to_F99_warp
else
  echo "  using pre-existing func-to-F99 warpfield"
fi
if [[ ! -r $transDir/F99_to_${funcBase}_warp.nii.gz ]] ; then
  convertwarp --ref=$funcDir/${funcBase}_brain_mask --warp1=$structDir/../transform/F99_to_${structBase}_warp --postmat=$transDir/${structBase}_to_${funcBase}.mat --out=$transDir/F99_to_${funcBase}_warp
else
  echo "  using pre-existing F99-to-func warpfield"
fi

# warp the F99 surface from F99 to functional space
mkdir -p $funcDir/surf
for hemi in left right ; do
  [[ $hemi == "left" ]] && surfF99=$surfLeft || surfF99=$surfRight
  surfFunc=$funcDir/surf/F99.$hemi.func.$surfName.fiducial.surf.gii
  if [[ ! -r $surfFunc ]] ; then
    $WBBIN/wb_command -surface-apply-warpfield $surfF99 $transDir/${funcBase}_to_F99_warp.nii.gz $surfFunc -fnirt $transDir/F99_to_${funcBase}_warp.nii.gz
  else
    echo "  using pre-existing $hemi F99 surface in functional space"
  fi
done

# prepare subcortical label masks in F99 space
if [[ $volSpace == "F99" ]] ; then
  echo "  warping subcortical data to F99"
  # warp the volumetric timeseries to F99 space
  applywarp --rel --interp=spline \
    -i $funcImg \
    -r $MRCATDIR/data/macaque/F99/subcortMask_2mm \
    -m $MRCATDIR/data/macaque/F99/subcortMask_2mm \
    -w $transDir/${funcBase}_to_F99_warp \
    -o ${funcImg}_F99

else
  # prepare subcortical label masks in functional space

  # combine affine and D99/F99 warps to get D99_to_${funcBase}
  if [[ ! -r $transDir/D99_to_${funcBase}_warp.nii.gz ]] ; then
    convertwarp --ref=$funcDir/${funcBase}_brain_mask --warp1=$MRCATDIR/data/macaque/transform/D99_to_F99_warp --warp2=$structDir/../transform/F99_to_${structBase}_warp --postmat=$transDir/${structBase}_to_${funcBase}.mat --out=$transDir/D99_to_${funcBase}_warp
  else
    echo "  using pre-existing D99-to-func warpfield"
  fi

  # warp the subcortical label file to functional space
  applywarp --rel --interp=nn \
    -i $MRCATDIR/data/macaque/D99/subcortLabel \
    -r $funcDir/${funcBase}_brain_mask \
    -m $funcDir/${funcBase}_brain_mask \
    -w $transDir/D99_to_${funcBase}_warp \
    -o $funcDir/subcortLabel

  # add the labels back in (first extract them from the original)
  tmpFile=$(mktemp "$funcDir/tmp.labels.XXXXXXXXXX")
  wb_command -volume-label-export-table $MRCATDIR/data/macaque/D99/subcortLabel.nii.gz 1 $tmpFile
  wb_command -volume-label-import $funcDir/subcortLabel.nii.gz $tmpFile $funcDir/subcortLabel.nii.gz -drop-unused-labels
  rm $tmpFile

  # the code below is from workbench and avoids importing labels again
  # but it does not support roi masking, without actually importing labels again
  #wb_command -volume-warpfield-resample \
  #  $MRCATDIR/data/macaque/D99/subcortLabel.nii.gz \
  #  $transDir/D99_to_${funcBase}_warp.nii.gz \
  #  $funcDir/${funcBase}_brain_mask.nii.gz \
  #  ENCLOSING_VOXEL \
  #  $funcDir/subcortLabel.nii.gz \
  #  -fnirt $MRCATDIR/data/macaque/D99/subcortLabel.nii.gz
fi


#=========================================
# Project to surface
#=========================================

echo "Projecting functional to surface"

# loop over hemispheres to project volume data to the surface
depth=1
for hemi in left right ; do
  [[ $hemi == "left" ]] && h=L || h=R

  # surface and projection
  surf=$funcDir/surf/F99.$hemi.func.$surfName.fiducial.surf.gii
  proj=$funcImg.$hemi.$surfName.func.gii

  # switch between projection methods
  case $projMethod in

    trilinear )
      # trilinear volume to surface mapping
      $WBBIN/wb_command -volume-to-surface-mapping $funcImg.nii.gz $surf $proj -trilinear
      ;;

    myelin )
      # bring masks from structural to functional space
      maskFuncBrain=$funcDir/${funcBase}_brain_mask
      for maskName in $hemi CSF WMcore ; do
        if [[ ! -r $funcDir/$maskName.nii.gz ]] ; then
          applywarp --rel --interp=nn -i $structDir/$maskName -r $maskFuncBrain --premat=$transDir/${structBase}_to_${funcBase}.mat -o $funcDir/$maskName
        fi
      done
      # create hemispere specific brain and GM masks (excluding CSF)
      if [[ ! -r $funcDir/${funcBase}_brain_${hemi}_mask.nii.gz ]] ; then
        fslmaths $maskFuncBrain -sub $funcDir/CSF -bin -mas $funcDir/$hemi $funcDir/${funcBase}_brain_${hemi}_mask
      fi
      if [[ ! -r $funcDir/ribbon_${hemi}_fake.nii.gz ]] ; then
        fslmaths $maskFuncBrain -sub $funcDir/CSF -sub $funcDir/WMcore -bin -mas $funcDir/$hemi $funcDir/ribbon_${hemi}_fake
      fi
      # myelin-style volume to surface mapping
      depth=2
      FWHM=2
      sigma=$(echo "$FWHM / ( 2 * ( sqrt ( 2 * l ( 2 ) ) ) )" | bc -l)
      ribbonFake=$funcDir/${funcBase}_brain_${hemi}_mask.nii.gz
      #ribbonFake=$funcDir/ribbon_${hemi}_fake.nii.gz # TODO: at some point I could consider to use this fake ribbon to project...
      thicknessFake=$funcDir/surf/thickness.$funcBaseProc.fake.shape.gii
      $WBBIN/wb_command -surface-vertex-areas $surf $thicknessFake
      $WBBIN/wb_command -metric-math "($depth+(data*0))" $thicknessFake -var "data" $thicknessFake > /dev/null
      $WBBIN/wb_command -volume-to-surface-mapping $funcImg.nii.gz $surf $proj -myelin-style $ribbonFake $thicknessFake $sigma
      rm $thicknessFake
      ;;

    *) >&2 echo "func to surf projection method not supported: $projMethod"; exit 1 ;;
  esac

done


#=========================================
# Create dtseries
#=========================================

echo "Creating dtseries"

# add subcortical structures in F99 space
if [[ $volSpace == "F99" ]] ; then

  $WBBIN/wb_command -cifti-create-dense-timeseries \
    $funcDir/${funcBaseProc}.$surfName.dtseries.nii \
    -volume ${funcImg}_F99.nii.gz $MRCATDIR/data/macaque/F99/subcortLabel_2mm.nii.gz \
    -left-metric $funcDir/${funcBaseProc}.left.$surfName.func.gii \
    -right-metric $funcDir/${funcBaseProc}.right.$surfName.func.gii

  # remove F99 volume data to make space
  rm ${funcImg}_F99.nii.gz

else

  # add subcortical structures in functional space
  $WBBIN/wb_command -cifti-create-dense-timeseries \
    $funcDir/${funcBaseProc}.$surfName.dtseries.nii \
    -volume $funcImg.nii.gz $funcDir/subcortLabel.nii.gz \
    -left-metric $funcDir/${funcBaseProc}.left.$surfName.func.gii \
    -right-metric $funcDir/${funcBaseProc}.right.$surfName.func.gii

fi


#=========================================
# cleanup
#=========================================

rm $funcDir/${funcBaseProc}.left.$surfName.func.gii
rm $funcDir/${funcBaseProc}.right.$surfName.func.gii
echo "  done"
