#!/usr/bin/env bash
umask u+rw,g+rw # give group read/write permissions to all new files
set -e    # stop immediately on error


# ------------------- #
# GENERAL DEFINITIONS
# ------------------- #
source $MRCATDIR/setupMrCat.sh
studyDir="/Volumes/rsfMRI/anaesthesia"
anaDir="$studyDir/analysis"
mkdir -p $anaDir/dconn
mkdir -p $anaDir/map

# try to retrieve the dataset suffices, or opt for defaults
[[ -f $anaDir/instruct/sourceConfig.sh ]] && source $anaDir/instruct/sourceConfig.sh
[[ -z $suffixClean ]] && suffixClean="WMCSF"
[[ -z $suffixConn ]] && suffixConn=".clean${suffixClean}"

# retrieve the instruction file
instructFile=$anaDir/instruct/instructCompareDenseConn.txt
[[ ! -s $instructFile ]] && echo "" && >&2 printf "\nError: no valid instruction file found at:\n%s\n\n" $instructFile && exit 1
[[ $(tail -c1 $instructFile | wc -l) -le 0 ]] && echo "" >> $instructFile

# start a timer
SECONDS=0


# --------------------------- #
# COMPARING DENSE-CONNECTOMES
# --------------------------- #
echo ""
echo "COMPARING DENSE-CONNECTOMES"

# create a temporary directory to store intermediate results
tmpDir=$(mktemp -d "$anaDir/tmp.scaleDenseConn.XXXXXXXXXX")

# loop over FUN sites
while read -r siteNameA siteNameB ; do
  echo ""
  echo "  scaling connectomes from \"$siteNameA\" with \"$siteNameB\""

  # specify the dense connectomes
  denseConnA=$anaDir/dconn/${siteNameA}${suffixConn}.dconn.nii
  denseConnB=$anaDir/dconn/${siteNameB}${suffixConn}.dconn.nii

  # taking the absolute coupling strength
  #echo "    representing connectomes in absolute values"
  #wb_command -cifti-math "abs(data)" $tmpDir/${siteNameA}${suffixConn}.dconn.nii -fixnan 0 -var "data" $denseConnA > /dev/null
  #wb_command -cifti-math "abs(data)" $tmpDir/${siteNameB}${suffixConn}.dconn.nii -fixnan 0 -var "data" $denseConnB > /dev/null

  # limiting the dense connectomes to only positive correlations
  echo "    ignoring weak connections"
  wb_command -cifti-math "(A*(A>0.02))" $tmpDir/${siteNameA}${suffixConn}.dconn.nii -fixnan 0 -var "A" $denseConnA > /dev/null
  wb_command -cifti-math "(B*(A>0.02))" $tmpDir/${siteNameB}${suffixConn}.dconn.nii -fixnan 0 -var "A" $denseConnA -var "B" $denseConnB > /dev/null
  #wb_command -cifti-math "(A*(A>0.2))" $tmpDir/${siteNameA}${suffixConn}.dconn.nii -fixnan 0 -var "A" $tmpDir/${siteNameA}${suffixConn}.dconn.nii > /dev/null
  #wb_command -cifti-math "(B*(A>0.2))" $tmpDir/${siteNameB}${suffixConn}.dconn.nii -fixnan 0 -var "A" $tmpDir/${siteNameA}${suffixConn}.dconn.nii -var "B" $tmpDir/${siteNameB}${suffixConn}.dconn.nii > /dev/null

  # compare dense-connectomes
  echo "    calculating the scaling factor"
  wb_command -cifti-math "log(B/A)" $tmpDir/${siteNameA}.${siteNameB}${suffixConn}.scale.dconn.nii -fixnan 0 -var "A" $tmpDir/${siteNameA}${suffixConn}.dconn.nii -var "B" $tmpDir/${siteNameB}${suffixConn}.dconn.nii > /dev/null
  wb_command -cifti-math "(data*(data>-1))" $tmpDir/${siteNameA}.${siteNameB}${suffixConn}.scale.dconn.nii -fixnan 0 -var "data" $tmpDir/${siteNameA}.${siteNameB}${suffixConn}.scale.dconn.nii > /dev/null

  # calculate the non-zero mean
  wb_command -cifti-reduce $tmpDir/${siteNameA}.${siteNameB}${suffixConn}.scale.dconn.nii SUM $tmpDir/${siteNameA}.${siteNameB}${suffixConn}.scale.sum.dscalar.nii -direction ROW
  wb_command -cifti-reduce $tmpDir/${siteNameA}.${siteNameB}${suffixConn}.scale.dconn.nii COUNT_NONZERO $tmpDir/${siteNameA}.${siteNameB}${suffixConn}.scale.nsamples.dscalar.nii -direction ROW
  wb_command -cifti-math "(sum/nSamples)" $anaDir/map/${siteNameA}.${siteNameB}${suffixConn}.scaleConn.dscalar.nii -fixnan 0 -var "sum" $tmpDir/${siteNameA}.${siteNameB}${suffixConn}.scale.sum.dscalar.nii -var "nSamples" $tmpDir/${siteNameA}.${siteNameB}${suffixConn}.scale.nsamples.dscalar.nii > /dev/null
  #rm $tmpDir/${siteNameA}.${siteNameB}${suffixConn}.scale.sum.dscalar.nii $tmpDir/${siteNameA}.${siteNameB}${suffixConn}.scale.nsamples.dscalar.nii

  echo "    calculating the difference"
  wb_command -cifti-math "(B-A)" $tmpDir/${siteNameA}.${siteNameB}${suffixConn}.diff.dconn.nii -fixnan 0 -var "A" $tmpDir/${siteNameA}${suffixConn}.dconn.nii -var "B" $tmpDir/${siteNameB}${suffixConn}.dconn.nii > /dev/null

  # calculate the non-zero mean
  wb_command -cifti-reduce $tmpDir/${siteNameA}.${siteNameB}${suffixConn}.diff.dconn.nii SUM $tmpDir/${siteNameA}.${siteNameB}${suffixConn}.diff.sum.dscalar.nii -direction ROW
  wb_command -cifti-reduce $tmpDir/${siteNameA}.${siteNameB}${suffixConn}.diff.dconn.nii COUNT_NONZERO $tmpDir/${siteNameA}.${siteNameB}${suffixConn}.diff.nsamples.dscalar.nii -direction ROW
  wb_command -cifti-math "(sum/nSamples)" $anaDir/map/${siteNameA}.${siteNameB}${suffixConn}.diffConn.dscalar.nii -fixnan 0 -var "sum" $tmpDir/${siteNameA}.${siteNameB}${suffixConn}.diff.sum.dscalar.nii -var "nSamples" $tmpDir/${siteNameA}.${siteNameB}${suffixConn}.diff.nsamples.dscalar.nii > /dev/null
  #rm $tmpDir/${siteNameA}.${siteNameB}${suffixConn}.diff.sum.dscalar.nii $tmpDir/${siteNameA}.${siteNameB}${suffixConn}.diff.nsamples.dscalar.nii

done < $instructFile


# clean-up
rm -r $tmpDir

echo ""
echo "DONE"
echo "  seconds elapsed: $SECONDS"
echo ""
