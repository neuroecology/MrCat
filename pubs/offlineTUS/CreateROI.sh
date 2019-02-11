#!/usr/bin/env bash
umask u+rw,g+rw # give group read/write permissions to all new files
set -e    # stop immediately on error


# ------------------- #
# GENERAL DEFINITIONS
# ------------------- #
source $MRCATDIR/setupMrCat.sh
labelFile=$MRCATDIR/data/macaque/F99/subcortLabel_2mm.nii.gz
anaDir="/Volumes/rsfMRI/anaesthesia/analysis"
roiDir=$anaDir/roi
roiRadius=4 # standard ROI radius in mm
roiBigRadius=10 # special larger radius
roiBigName="Big" # example "11", name of ROI with a larger radius

# retrieve the instruction file
instructFile=$anaDir/instruct/instructCreateRoi.txt
[[ ! -s $instructFile ]] && echo "" && >&2 printf "\nError: no valid instruction file found at:\n%s\n\n" $instructFile && exit 1
[[ $(tail -c1 $instructFile | wc -l) -le 0 ]] && echo "" >> $instructFile

# create ROI directories
mkdir -p $roiDir/vol
mkdir -p $roiDir/surf
mkdir -p $roiDir/coord
mkdir -p $roiDir/border

# create a temporary directory to store the intermediate ROIs
tmpDir=$(mktemp -d "$roiDir/tmp.createROI.XXXXXXXXXX")

# start a timer
SECONDS=0


# ---------------------------- #
# CREATING REGIONS-OF-INTEREST
# ---------------------------- #
echo ""
echo "CREATING REGIONS-OF-INTEREST"

# test wheather all selected ROIs are of the 'nearby' type
flgNearby=0
while read -r roiName flgSurfVol ; do
  flgNearby=$(awk '($1 == "'$roiName'"){print 1; exit}' $roiDir/coord/nearby.txt)
  [[ $flgNearby -ne 1 ]] && break
done < $instructFile

# if all selected ROIs are 'nearby', do not allow overlap
[[ $flgNearby -eq 1 ]] && cmdOverlap="-overlap-logic CLOSEST" || cmdOverlap=""
cmdOverlap="-overlap-logic CLOSEST"

# initialise roi lists
> $tmpDir/name.surf.txt
> $tmpDir/name.vol.txt
> $tmpDir/coord.MNI.left.txt
> $tmpDir/coord.MNI.right.txt

# loop over ROIs
echo "extracting ROI coordinates"
while read -r roiName flgSurfVol ; do

  # test if this is listed as a special big ROI
  if [[ $roiName =~ $roiBigName ]] ; then
    suffixBig=$roiBigName
    roiName=${roiName%%$suffixBig}
  else
    suffixBig=""
  fi

  # test if this ROI is listed as a volumetric ROI
  flgVol=$(awk '{flg=0} ($1 == "'$roiName'"){flg=1; exit} END {print flg}' $roiDir/coord/volumetric.txt)

  # if the ROI space is not specified
  if [[ -z $flgSurfVol ]] ; then
    # set to volume-based when present in the volume list, otherwise assume ROI is surface-based
    [[ $flgVol -eq 1 ]] && flgSurfVol="vol" || flgSurfVol="surf"
  fi

  # process the surface ROI
  if [[ $flgSurfVol =~ surf ]] ; then

    # add roi to list of surface ROIs, adjust name if this ROI is also listed as an volumetric ROI
    if [[ $flgVol -eq 1 ]] ; then
      echo "${roiName}${suffixBig}.surf" >> $tmpDir/name.surf.txt
    else
      echo "${roiName}${suffixBig}" >> $tmpDir/name.surf.txt
    fi

    # determine if current ROI is a "site", "nearby" or "remote" ROI
    flgRoi=""
    flgRoi=$(awk '($3 == "'$roiName'"){print "site"; exit}' $roiDir/coord/site.txt)
    [[ -z $flgRoi ]] && flgRoi=$(awk '($1 == "'$roiName'"){print "nearby"; exit}' $roiDir/coord/nearby.txt)
    [[ -z $flgRoi ]] && flgRoi=$(awk '($1 == "'$roiName'"){print "remote"; exit}' $roiDir/coord/remote.txt)

    # return error when ROI is not found
    [[ -z $flgRoi ]] && echo "error: ROI \"$roiName\" not found in any list in $roiDir/coord" && exit 1

    # switch depending on type of ROI
    case $flgRoi in
      site )
        # average coordinates in MNI space and write to left and right coordinate files
        awk '($3 == "'$roiName'"){ n+=1; X+=$5; Y+=$6; Z+=$7 } END { print (X/n),(Y/n),(Z/n) }' $roiDir/coord/site.txt >> $tmpDir/coord.MNI.left.txt
        awk '($3 == "'$roiName'"){ n+=1; X+=$8; Y+=$9; Z+=$10 } END { print (X/n),(Y/n),(Z/n) }' $roiDir/coord/site.txt >> $tmpDir/coord.MNI.right.txt
        ;;
      * )
        # separate left/right and right coordinate files
        awk '($1 == "'$roiName'"){print $2,$3,$4}' $roiDir/coord/$flgRoi.txt >> $tmpDir/coord.MNI.left.txt
        awk '($1 == "'$roiName'"){print $5,$6,$7}' $roiDir/coord/$flgRoi.txt >> $tmpDir/coord.MNI.right.txt
        ;;
    esac

  fi # if [[ $flgSurfVol =~ surf ]] ; then


  # add roi to list of volumetric (sub-cortical) ROIs
  if [[ $flgSurfVol =~ vol ]] ; then

    # return error when ROI is not found
    [[ $flgVol -ne 1 ]] && >&2 echo "error: ROI \"$roiName\" not found in $roiDir/coord/volumetric.txt" && exit 1

    # add roi to list of surface ROIs
    echo "$roiName" >> $tmpDir/name.vol.txt

  fi

done < $instructFile


# process the surface ROIs
if [[ -s $tmpDir/name.surf.txt ]] ; then

  # warp MNI coordinates to F99 space
  echo "warping coordinates to F99"
  MNIref=$MRCATDIR/data/macaque/MNI/MNI
  F99ref=$MRCATDIR/data/macaque/F99/F99
  warp=$MRCATDIR/data/macaque/transform/F99_to_MNI_warp
  std2imgcoord -std $MNIref -img $F99ref -warp $warp -mm $tmpDir/coord.MNI.left.txt > $tmpDir/coord.F99.left.txt
  std2imgcoord -std $MNIref -img $F99ref -warp $warp -mm $tmpDir/coord.MNI.right.txt > $tmpDir/coord.F99.right.txt

  # project to surface, for each hemisphere
  echo "projecting to surface"
  for hemi in left right ; do
    echo "  $hemi hemisphere"
    [[ $hemi == "left" ]] && h=l || h=r

    # specify the surface and cortical GM mask
    surf=$anaDir/surf/${h}h.fiducial.10k.surf.gii
    surfMask=$roiDir/surf/cortex.$hemi.shape.gii

    # convert coordinates to vertices on the F99 fiducial surface
    wb_command -surface-closest-vertex $surf $tmpDir/coord.F99.$hemi.txt $tmpDir/vertex.$hemi.txt

    # create a point-roi from these vertices
    wb_command -surface-geodesic-rois $surf $roiRadius $tmpDir/vertex.$hemi.txt $tmpDir/roi.$hemi.shape.gii $cmdOverlap

    # when so specified in $roiBigName, play a trick to incorporate an extra big ROI

    if [[ -n $(grep "$roiBigName$" $tmpDir/name.surf.txt) ]] ; then

      # create a point-roi from these vertices with a larger ROI radius
      wb_command -surface-geodesic-rois $surf $roiBigRadius $tmpDir/vertex.$hemi.txt $tmpDir/roi_big.$hemi.shape.gii

      # find the column index of the big ROI
      idxCol=$(cat $tmpDir/name.surf.txt | awk '($1 ~ "'$roiBigName'$"){print NR; exit}')
      maxCol=$(wc -l $tmpDir/name.surf.txt | awk '{print $1}')

      # merge the normal and big ROIs back together.
      cmdMerge=""
      [[ $idxCol -gt 1 ]] && cmdMerge+=" -metric $tmpDir/roi.$hemi.shape.gii -column 1 -up-to $((idxCol-1))"
      cmdMerge+=" -metric $tmpDir/roi_big.$hemi.shape.gii -column $idxCol"
      [[ $idxCol -lt $maxCol ]] && cmdMerge+=" -metric $tmpDir/roi.$hemi.shape.gii -column $((idxCol+1)) -up-to $maxCol"
      wb_command -metric-merge $tmpDir/roi.$hemi.shape.gii $cmdMerge

    fi

    # set data on the medial wall to zeros
    $RUN wb_command -metric-math "(data*mask)" $tmpDir/roi_tmp.$hemi.shape.gii \
      -var "data" $tmpDir/roi.$hemi.shape.gii \
      -var "mask" $roiDir/surf/cortex.$hemi.shape.gii -column 1 -repeat > /dev/null

    # clean up (different file name was used to avoid computing output in memory)
    mv -f $tmpDir/roi_tmp.$hemi.shape.gii $tmpDir/roi.$hemi.shape.gii

    # assign names to maps
    wb_command -set-map-names $tmpDir/roi.$hemi.shape.gii -name-file $tmpDir/name.surf.txt

    # create borders based on ROIs
    wb_command -metric-rois-to-border $surf $tmpDir/roi.$hemi.shape.gii ROI $roiDir/border/roi.$hemi.border

    # make empty surface ROIs for the contralateral hemisphere
    wb_command -metric-math "(data*0)" $tmpDir/empty.$hemi.shape.gii -var "data" $tmpDir/roi.$hemi.shape.gii > /dev/null

  done

  # extract an empty volumetric ROI from the label file
  wb_command -volume-label-to-roi $labelFile $tmpDir/empty.surfRoi.nii.gz -name AMYGDALA_LEFT
  wb_command -volume-math "(data*0)" $tmpDir/empty.surfRoi.nii.gz -var "data" $tmpDir/empty.surfRoi.nii.gz > /dev/null

  # repeat this empty volumetric ROI to match the surface ROIs
  nRoiSurf=$(wc -l < $tmpDir/name.surf.txt)
  cmdMerge=""
  for c in $(seq 1 $nRoiSurf) ; do
    cmdMerge+=" -volume $tmpDir/empty.surfRoi.nii.gz"
  done
  wb_command -volume-merge $tmpDir/empty.surfRoi.nii.gz $cmdMerge

  # store commands to merge the left surface ROIs
  cmdMergeSurfRoiLeftHemiLeft=" -metric $tmpDir/roi.left.shape.gii"
  cmdMergeSurfRoiLeftHemiRight=" -metric $tmpDir/empty.right.shape.gii"
  cmdMergeSurfRoiRightHemiLeft=" -metric $tmpDir/empty.left.shape.gii"
  cmdMergeSurfRoiRightHemiRight=" -metric $tmpDir/roi.right.shape.gii"
  cmdMergeSurfRoiVol=" -volume $tmpDir/empty.surfRoi.nii.gz"

else

  # no surface ROIs to merge
  cmdMergeSurfRoiLeftHemiLeft=""
  cmdMergeSurfRoiLeftHemiRight=""
  cmdMergeSurfRoiRightHemiLeft=""
  cmdMergeSurfRoiRightHemiRight=""
  cmdMergeSurfRoiVol=""

fi # if [[ -s $tmpDir/name.surf.txt ]] ; then


# process the volumetric ROIs
if [[ -s $tmpDir/name.vol.txt ]] ; then
  echo "processing volumetric ROIs"
  c=0

  # loop over volumetric ROIs
  while read -r roiName ; do
    ((++c))

    # retreive the names of the label
    labelLeft=$(awk '($1 == "'$roiName'"){print $2; exit}' $roiDir/coord/volumetric.txt)
    labelRight=$(awk '($1 == "'$roiName'"){print $3; exit}' $roiDir/coord/volumetric.txt)

    # extract the volumetric (sub-cortical) ROI
    for hemi in left right ; do
      [[ $hemi == left ]] && labelName=$labelLeft || labelName=$labelRight

      # extract the ROI from the label file
      wb_command -volume-label-to-roi $labelFile $tmpDir/tmp.$hemi.nii.gz -name $labelName

      # store or append the ROI
      if [[ $c -le 1 ]] ; then
        mv $tmpDir/tmp.$hemi.nii.gz $tmpDir/roi.$hemi.nii.gz
      else
        wb_command -volume-merge $tmpDir/roi.$hemi.nii.gz -volume $tmpDir/roi.$hemi.nii.gz -volume $tmpDir/tmp.$hemi.nii.gz
        rm -f $tmpDir/tmp.$hemi.nii.gz
      fi

    done

  done < $tmpDir/name.vol.txt

  # create a command to repeat the empty surface ROI, matching the volumetric ROIs
  nRoiVol=$(wc -l < $tmpDir/name.vol.txt)
  cmdMerge=""
  for c in $(seq 1 $nRoiVol) ; do
    cmdMerge+=" -column 1"
  done

  # loop over hemispheres
  for hemi in left right ; do

    # ensure an empty surface ROI exists (if not already created)
    if [[ ! -s $tmpDir/name.surf.txt ]] ; then
      [[ $hemi == left ]] && h=l || h=r
      echo "0 0 0" > $tmpDir/coord.txt
      surf=$MRCATDIR/surfops/macaque_10k_surf/${h}h.fiducial.10k.surf.gii
      wb_command -surface-geodesic-rois $surf 0 $tmpDir/coord.txt $tmpDir/empty.$hemi.shape.gii
      wb_command -metric-math "(data*0)" $tmpDir/empty.$hemi.shape.gii -var "data" $tmpDir/empty.$hemi.shape.gii
    fi

    # create matching empty surface ROIs
    wb_command -metric-merge $tmpDir/empty.volRoi.$hemi.shape.gii -metric $tmpDir/empty.$hemi.shape.gii $cmdMerge

  done

  # store commands to merge the left and right volumetric ROIs
  cmdMergeVolRoiHemiLeft=" -metric $tmpDir/empty.volRoi.left.shape.gii"
  cmdMergeVolRoiHemiRight=" -metric $tmpDir/empty.volRoi.right.shape.gii"
  cmdMergeVolRoiLeft=" -volume $tmpDir/roi.left.nii.gz"
  cmdMergeVolRoiRight=" -volume $tmpDir/roi.right.nii.gz"

else

  # no volumetric ROIs to merge
  cmdMergeVolRoiHemiLeft=""
  cmdMergeVolRoiHemiRight=""
  cmdMergeVolRoiLeft=""
  cmdMergeVolRoiRight=""

fi # if [[ -s $tmpDir/name.vol.txt ]] ; then


# concatenate the surface and volumetric ROIs
wb_command -metric-merge $tmpDir/roileft.surfleft.shape.gii $cmdMergeSurfRoiLeftHemiLeft $cmdMergeVolRoiHemiLeft
wb_command -metric-merge $tmpDir/roileft.surfright.shape.gii $cmdMergeSurfRoiLeftHemiRight $cmdMergeVolRoiHemiRight
wb_command -metric-merge $tmpDir/roiright.surfleft.shape.gii $cmdMergeSurfRoiRightHemiLeft $cmdMergeVolRoiHemiLeft
wb_command -metric-merge $tmpDir/roiright.surfright.shape.gii $cmdMergeSurfRoiRightHemiRight $cmdMergeVolRoiHemiRight
wb_command -volume-merge $tmpDir/roileft.nii.gz $cmdMergeSurfRoiVol $cmdMergeVolRoiLeft
wb_command -volume-merge $tmpDir/roiright.nii.gz $cmdMergeSurfRoiVol $cmdMergeVolRoiRight

# combine all surface and volumetric ROIs for the left and right hemisphere
for hemi in left right ; do
  wb_command -cifti-create-dense-scalar $tmpDir/roi.$hemi.dscalar.nii \
    -volume $tmpDir/roi${hemi}.nii.gz $labelFile \
    -left-metric $tmpDir/roi${hemi}.surfleft.shape.gii \
    -right-metric $tmpDir/roi${hemi}.surfright.shape.gii
done

# create a bilateral ROI cifti
wb_command -cifti-math "max(left,right)" $tmpDir/roi.bilat.dscalar.nii \
  -var "left" $tmpDir/roi.left.dscalar.nii \
  -var "right" $tmpDir/roi.right.dscalar.nii > /dev/null

# merge the hemisphere ROIs into a single cifti
wb_command -cifti-merge $roiDir/roi.dscalar.nii -cifti $tmpDir/roi.bilat.dscalar.nii -cifti $tmpDir/roi.left.dscalar.nii -cifti $tmpDir/roi.right.dscalar.nii

# add the bilat, left, and right hemisphere names
for hemi in bilat left right ; do
  cat $tmpDir/name.surf.txt $tmpDir/name.vol.txt | awk '{print $1 "." "'$hemi'"}' > $tmpDir/name.$hemi.txt
done
cat $tmpDir/name.bilat.txt $tmpDir/name.left.txt $tmpDir/name.right.txt > $roiDir/name.txt

# assign names to the ROI cifti file
wb_command -set-map-names $roiDir/roi.dscalar.nii -name-file $roiDir/name.txt

# reorder ROIs alphabetically
sort -f $roiDir/name.txt > $tmpDir/name.reorder.txt
nl $roiDir/name.txt | sort -f -k 2 | awk '{print $1}' > $tmpDir/idx.reorder.txt
wb_command -cifti-reorder $roiDir/roi.dscalar.nii ROW $tmpDir/idx.reorder.txt $roiDir/roi.dscalar.nii
mv $tmpDir/name.reorder.txt $roiDir/name.txt

# create a single combined maximum-projection ROI
wb_command -cifti-reduce $roiDir/roi.dscalar.nii MAX $roiDir/roi.combined.dscalar.nii

# clean-up
rm -rf $tmpDir

echo ""
echo "DONE"
echo "  seconds elapsed: $SECONDS"
echo ""
