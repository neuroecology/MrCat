#!/usr/bin/env bash
umask u+rw,g+rw # give group read/write permissions to all new files
set -e    # stop immediately on error

# when input arguments are provided, use these rather than the instruction file
[[ $# -gt 0 ]] && siteList="$*" || siteList=""

# ------------------- #
# GENERAL DEFINITIONS
# ------------------- #
source $MRCATDIR/setupMrCat.sh
studyDir="/Volumes/rsfMRI/anaesthesia"
procDir="$studyDir/proc"
anaDir="$studyDir/analysis"
mkdir -p $anaDir/dconn

# try to retrieve the dataset suffices, or opt for defaults
[[ -f $anaDir/instruct/sourceConfig.sh ]] && source $anaDir/instruct/sourceConfig.sh
[[ -z $suffixClean ]] && suffixClean="WMCSF"
[[ -z $suffixTS ]] && suffixTS="_hpbs_clean${suffixClean}_lp.smooth"
[[ -z $suffixConn ]] && suffixConn=".clean${suffixClean}"
[[ -z $flgValidate ]] && flgValidate=0 && suffixValidate=""
[[ -z $suffixAnaLevelList ]] && suffixAnaLevelList="group"


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
# CALCULATING DENSE-CONNECTOME
# ---------------------------- #
echo ""
echo "CALCULATING CROSS-CORRELATION DENSE-CONNECTOME"


# loop over FUN sites
while read -r siteName ; do
  echo ""
  echo "  FUN site: $siteName"

  # loop over analysis levels
  for suffixAnaLevel in $suffixAnaLevelList ; do

    # report progress per analysis level
    if [[ $(echo $suffixAnaLevelList | wc -w) -gt 1 ]] ; then
      echo "    level: $suffixAnaLevel"
    fi

    # no extra suffix needed for group level analysis
    [[ $suffixAnaLevel == "group" ]] && suffixAnaLevel=""
    [[ $suffixAnaLevel == "none" ]] && suffixAnaLevel=""

    # specify where the whole-brain time-series can be found and the dense connectome will be stored
    siteTimeSeriesData=$procDir/$siteName/func${suffixAnaLevel}${suffixTS}${suffixValidate}.F99_10k.dtseries.nii
    denseConn=$anaDir/dconn/${siteName}${suffixAnaLevel}${suffixConn}.dconn.nii

    # calculating dense-connectome
    wb_command -cifti-correlation $siteTimeSeriesData $denseConn -fisher-z -mem-limit 8

    # make sure the medial wall is excluded
    wb_command -cifti-restrict-dense-map $denseConn ROW $denseConn -cifti-roi $MRCATDIR/data/macaque/F99/surf/cortex_subcort.roi.F99_10k.dscalar.nii
    wb_command -cifti-restrict-dense-map $denseConn COLUMN $denseConn -cifti-roi $MRCATDIR/data/macaque/F99/surf/cortex_subcort.roi.F99_10k.dscalar.nii

    # limit the values from -2 to 2 (shh, be silent)
    wb_command -cifti-math "clamp(data,(-2),2)" $denseConn -fixnan 0 -var "data" $denseConn > /dev/null

  done

done < $instructFileTmp

# clean-up
rm -f $instructFileTmp


echo ""
echo "DONE"
echo "  seconds elapsed: $SECONDS"
echo ""
