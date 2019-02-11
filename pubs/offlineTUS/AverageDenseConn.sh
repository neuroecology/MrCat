#!/usr/bin/env bash
umask u+rw,g+rw # give group read/write permissions to all new files
set -e    # stop immediately on error

# when input arguments are provided, use these rather than the instruction file
[[ $# -gt 0 ]] && siteList="$*" || siteList=""

# ignore negative connections?
flgIgnoreNeg=0


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
[[ -z $suffixTS ]] && suffixTS="_hpbs_clean${suffixClean}_lp.smooth"
[[ -z $suffixConn ]] && suffixConn=".clean${suffixClean}"

# set an instruction file
instructFileTmp=$(mktemp "$anaDir/instruct/tmp.denseConnInstruct.XXXXXXXXXX")
if [[ -n $siteList ]] ; then

  echo $siteList | tr ' ' '\n' > $instructFileTmp

else

  # retrieve the instruction file
  instructFile=$anaDir/instruct/instructDenseConn.txt
  [[ ! -s $instructFile ]] && echo "" && >&2 printf "\nError: no valid instruction file found at:\n%s\n\n" $instructFile && exit 1
  [[ $(tail -c1 $instructFile | wc -l) -le 0 ]] && echo "" >> $instructFile

  # copy to the temporary instruction file
  cp $instructFile $instructFileTmp

fi

# start a timer
SECONDS=0


# ---------------------------- #
# AVERAGING DENSE-CONNECTOME
# ---------------------------- #
echo ""
echo "AVERAGING DENSE-CONNECTOME"


# loop over FUN sites
while read -r siteName ; do
  echo ""
  echo "  FUN site: $siteName"

  # specify where the dense connectome is stored
  denseConn=$anaDir/dconn/${siteName}${suffixConn}.dconn.nii
  denseConnMean=$anaDir/map/${siteName}${suffixConn}.meanConn.dscalar.nii

  # ignore negative values
  if [[ $flgIgnoreNeg -eq 1 ]] ; then
    denseConnOrig=$denseConn
    denseConn=$anaDir/dconn/${siteName}${suffixConn}.pos.dconn.nii
    wb_command -cifti-math "(dconn*(dconn>0))" $denseConn -var "dconn" $denseConnOrig > /dev/null
  fi

  # calculating the average across vertices
  wb_command -cifti-reduce $denseConn MEAN $denseConnMean -direction ROW -only-numeric

  # clean-up
  [[ $flgIgnoreNeg -eq 1 ]] && rm -f $denseConn

done < $instructFileTmp

# clean-up
rm -f $instructFileTmp


echo ""
echo "DONE"
echo "  seconds elapsed: $SECONDS"
echo ""
