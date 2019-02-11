#!/usr/bin/env bash
umask u+rw,g+rw # give group read/write permissions to all new files
set -e    # stop immediately on error


# ------------------- #
# GENERAL DEFINITIONS
# ------------------- #
source $MRCATDIR/setupMrCat.sh
studyDir="/Volumes/rsfMRI/anaesthesia"
anaDir="$studyDir/analysis"
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

# loop over FUN sites
while read -r siteNameA siteNameB ; do
  echo ""
  echo "  comparing connectomes (pair-wise correlation) between \"$siteNameA\" and \"$siteNameB\""

  # specify the dense connectomes
  denseConnA=$anaDir/dconn/${siteNameA}${suffixConn}.dconn.nii
  denseConnB=$anaDir/dconn/${siteNameB}${suffixConn}.dconn.nii

  # calculating correlation across dense-connectomes
  #wb_command -cifti-cross-correlation $denseConnA $denseConnB $anaDir/dconn/${siteNameA}.${siteNameB}${suffixConn}.crosscorr.dconn.nii -fisher-z -mem-limit 8
  wb_command -cifti-pairwise-correlation $denseConnA $denseConnB $anaDir/map/${siteNameA}.${siteNameB}${suffixConn}.crosscorr.dscalar.nii -fisher-z

done < $instructFile


echo ""
echo "DONE"
echo "  seconds elapsed: $SECONDS"
echo ""
