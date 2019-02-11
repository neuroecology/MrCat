#!/usr/bin/env bash
umask u+rw,g+rw # give group read/write permissions to all new files
set -e    # stop immediately on error

# list of matches between HCP structures (left) and Freesurfer labels (right)
# Freesurfer labels: $HCPPIPELINEDIR/global/confib/FreeSurferAllLut.txt
# HCP/Freesurfer labels: $HCPPIPELINEDIR/global/config/WholeBrainFreeSurferTrajectoryLabelTableLut.txt
# HCP labels: wb_command -set-structure
# ---------------------------------------------------------------------------
# CORTEX_LEFT LEFT-CEREBRAL-CORTEX
# CORTEX_RIGHT RIGHT-CEREBRAL-CORTEX
# CEREBELLUM <LEFT-CEREBELLUM-EXTERIOR>
# ACCUMBENS_LEFT LEFT-ACCUMBENS-AREA
# ACCUMBENS_RIGHT RIGHT-ACCUMBENS-AREA
# ALL_GREY_MATTER <GRAYMATTER-FSL-FAST>
# ALL_WHITE_MATTER <WHITEMATTER-FSL-FAST>
# AMYGDALA_LEFT LEFT-AMYGDALA
# AMYGDALA_RIGHT RIGHT-AMYGDALA
# BRAIN_STEM BRAIN-STEM
# CAUDATE_LEFT LEFT-CAUDATE
# CAUDATE_RIGHT RIGHT-CAUDATE
# CEREBELLAR_WHITE_MATTER_LEFT LEFT-CEREBELLUM-WHITE-MATTER
# CEREBELLAR_WHITE_MATTER_RIGHT RIGHT-CEREBELLUM-WHITE-MATTER
# CEREBELLUM_LEFT LEFT-CEREBELLUM-CORTEX
# CEREBELLUM_RIGHT RIGHT-CEREBELLUM-CORTEX
# CEREBRAL_WHITE_MATTER_LEFT LEFT-CEREBRAL-WHITE-MATTER
# CEREBRAL_WHITE_MATTER_RIGHT RIGHT-CEREBRAL-WHITE-MATTER
# CORTEX CEREBRAL_CORTEX
# DIENCEPHALON_VENTRAL_LEFT LEFT-VENTRALDC
# DIENCEPHALON_VENTRAL_RIGHT RIGHT-VENTRALDC
# HIPPOCAMPUS_LEFT LEFT-HIPPOCAMPUS
# HIPPOCAMPUS_RIGHT RIGHT-HIPPOCAMPUS
# INVALID <SUSPICIOUS>
# OTHER <LEFT-UNDETERMINED>
# OTHER_GREY_MATTER <CTX-LH-UNKNOWN>
# OTHER_WHITE_MATTER <WM-LH-UNKNOWN>
# PALLIDUM_LEFT LEFT-PALLIDUM
# PALLIDUM_RIGHT RIGHT-PALLIDUM
# PUTAMEN_LEFT LEFT-PUTAMEN
# PUTAMEN_RIGHT RIGHT-PUTAMEN
# THALAMUS_LEFT LEFT-THALAMUS-PROPER
# THALAMUS_RIGHT RIGHT-THALAMUS-PROPER

# ------------------- #
# GENERAL DEFINITIONS
# ------------------- #
workDir=$MRCATDIR/projects/fun/subcort
lutFile=$workDir/HCP_Structures_LookUpTable.txt
structureList="AMYGDALA_LEFT AMYGDALA_RIGHT CAUDATE_LEFT CAUDATE_RIGHT CEREBELLUM_LEFT CEREBELLUM_RIGHT HIPPOCAMPUS_LEFT HIPPOCAMPUS_RIGHT THALAMUS_LEFT THALAMUS_RIGHT"

# start a timer
SECONDS=0


# -------------------------------- #
# CREATING A VOLUMETRIC LABEL FILE
# -------------------------------- #
echo ""
echo "CREATING A VOLUMETRIC LABEL FILE"

# loop over spaces
for space in F99 D99 ; do
  echo "space: $space"

  # create an initial empty volumetric label file
  fslmaths $workDir/$space/"$(echo $structureList | awk '{print $1}')" -mul 0 $workDir/$space/subcortLabel

  # loop over structures
  for structure in $structureList ; do
    echo "  $structure"
    # extract the label index of the current structure from the look-up table
    val=$(awk 'f{print $1; f=0} /^'$structure'$/{f=1}' $lutFile)
    # when in conflict, overwrite existing voxel assignment
    fslmaths $workDir/$space/$structure -binv -mul $workDir/$space/subcortLabel $workDir/$space/subcortLabel
    # multiply the binary mask with this index and add to the label file
    fslmaths $workDir/$space/$structure -bin -mul $val -add $workDir/$space/subcortLabel $workDir/$space/subcortLabel
  done

  # convert to label file
  echo "  converting to label file"
  wb_command -volume-label-import $workDir/$space/subcortLabel.nii.gz $lutFile $workDir/$space/subcortLabel.nii.gz -drop-unused-labels

done

# rename the F99 subcortical label
mv $workDir/F99/subcortLabel.nii.gz $workDir/F99/subcortLabel_masked.nii.gz

# create a D99 mask
fslmaths $workDir/D99/subcortLabel -bin $workDir/D99/subcortMask


echo "warping D99 to F99"

# high-resolution
echo "  high-res 0.5mm"
wb_command -volume-warpfield-resample \
  $workDir/D99/subcortLabel.nii.gz \
  $MRCATDIR/data/macaque/transform/D99_to_F99_warp.nii.gz \
  $MRCATDIR/data/macaque/F99/F99.nii.gz \
  ENCLOSING_VOXEL \
  $workDir/F99/subcortLabel.nii.gz \
  -fnirt $workDir/D99/subcortLabel.nii.gz
fslmaths $workDir/F99/subcortLabel -bin $workDir/F99/subcortMask

# medium resolution
echo "  med-res 1mm"
flirt -in $workDir/F99/subcortMask -ref $workDir/F99/subcortMask -out $workDir/F99/subcortMask_1mm -applyisoxfm 1
wb_command -volume-warpfield-resample \
  $workDir/D99/subcortLabel.nii.gz \
  $MRCATDIR/data/macaque/transform/D99_to_F99_warp.nii.gz \
  $workDir/F99/subcortMask_1mm.nii.gz \
  ENCLOSING_VOXEL \
  $workDir/F99/subcortLabel_1mm.nii.gz \
  -fnirt $workDir/D99/subcortLabel.nii.gz
fslmaths $workDir/F99/subcortLabel_1mm -bin $workDir/F99/subcortMask_1mm

# low resolution
echo "  low-res 2mm"
flirt -in $workDir/F99/subcortMask -ref $workDir/F99/subcortMask -out $workDir/F99/subcortMask_2mm -applyisoxfm 2
wb_command -volume-warpfield-resample \
  $workDir/D99/subcortLabel.nii.gz \
  $MRCATDIR/data/macaque/transform/D99_to_F99_warp.nii.gz \
  $workDir/F99/subcortMask_2mm.nii.gz \
  ENCLOSING_VOXEL \
  $workDir/F99/subcortLabel_2mm.nii.gz \
  -fnirt $workDir/D99/subcortLabel.nii.gz
fslmaths $workDir/F99/subcortLabel_2mm -bin $workDir/F99/subcortMask_2mm

# copying the F99 label file to data/macaque
cp $workDir/D99/subcortLabel.nii.gz $MRCATDIR/data/macaque/D99/subcortLabel.nii.gz
cp $workDir/D99/subcortMask.nii.gz $MRCATDIR/data/macaque/D99/subcortMask.nii.gz
cp $workDir/F99/subcortLabel.nii.gz $MRCATDIR/data/macaque/F99/subcortLabel.nii.gz
cp $workDir/F99/subcortMask.nii.gz $MRCATDIR/data/macaque/F99/subcortMask.nii.gz
cp $workDir/F99/subcortLabel_1mm.nii.gz $MRCATDIR/data/macaque/F99/subcortLabel_1mm.nii.gz
cp $workDir/F99/subcortMask_1mm.nii.gz $MRCATDIR/data/macaque/F99/subcortMask_1mm.nii.gz
cp $workDir/F99/subcortLabel_2mm.nii.gz $MRCATDIR/data/macaque/F99/subcortLabel_2mm.nii.gz
cp $workDir/F99/subcortMask_2mm.nii.gz $MRCATDIR/data/macaque/F99/subcortMask_2mm.nii.gz


# update the GM and WM-CSF roi files (if the external drive is connected)
roiDir=/Volumes/rsfMRI/anaesthesia/analysis/roi
if [[ -d $roiDir ]] ; then
  mkdir -p $roiDir/vol

  # copy the label and mask files
  cp $MRCATDIR/data/macaque/F99/subcortLabel_2mm.nii.gz $roiDir/vol/subcortLabel_2mm.nii.gz
  cp $MRCATDIR/data/macaque/F99/subcortMask_2mm.nii.gz $roiDir/vol/subcortMask_2mm.nii.gz

  # construct a dense cifti ROI file
  wb_command -cifti-create-dense-scalar $roiDir/GM.dscalar.nii -volume $roiDir/vol/subcortMask_2mm.nii.gz $roiDir/vol/subcortLabel_2mm.nii.gz -left-metric $roiDir/surf/GM.left.shape.gii -right-metric $roiDir/surf/GM.right.shape.gii
  wb_command -cifti-create-dense-scalar $roiDir/WMCSF.dscalar.nii -volume $roiDir/vol/subcortMask_empty_2mm.nii.gz $roiDir/vol/subcortLabel_2mm.nii.gz -left-metric $roiDir/surf/WMCSF.left.shape.gii -right-metric $roiDir/surf/WMCSF.right.shape.gii

fi


echo ""
echo "DONE"
echo "  seconds elapsed: $SECONDS"
echo ""
