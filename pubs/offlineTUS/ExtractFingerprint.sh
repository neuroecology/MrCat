#!/usr/bin/env bash
umask u+rw,g+rw # give group read/write permissions to all new files
set -e    # stop immediately on error

# ------------------- #
# GENERAL DEFINITIONS
# ------------------- #
source $MRCATDIR/setupMrCat.sh
anaDir="/Volumes/rsfMRI/anaesthesia/analysis"
fingerprintDir="$anaDir/fingerprint"
mkdir -p $fingerprintDir

# try to retrieve the dataset suffices, or opt for defaults
[[ -f $anaDir/instruct/sourceConfig.sh ]] && source $anaDir/instruct/sourceConfig.sh
[[ -z $suffixClean ]] && suffixClean="WMCSF"
[[ -z $suffixConn ]] && suffixConn=".clean${suffixClean}"
[[ -z $flgValidate ]] && flgValidate=0 && suffixValidate=""
[[ -z $flgCapStat ]] && flgCapStat=1
[[ -z $flgLevel ]] && flgLevel="SUBJRUN_SUBJ_RUN_GROUP" # specify the analysis level: SUBJRUN, RUN, SESS, SUBJ, GROUP, or any combination (RUN_SUBJ_GROUP)
flgLevel="_${flgLevel}_" # pad with lines to make regular expressions easier

# make a sub-directory for validation fingerprints
[[ $flgValidate -eq 1 ]] && fingerprintDir="$fingerprintDir/validation" && mkdir -p $fingerprintDir

# make a sub-directory for uncapped fingerprints
[[ $flgCapStat -eq 0 ]] && fingerprintDir="$fingerprintDir/noCap" && mkdir -p $fingerprintDir

# set the fingerprint summary statistic
[[ -z $flgSummaryStat ]] && flgSummaryStat="MEAN"
[[ $flgSummaryStat == "MEDIAN" ]] && fingerprintDir="$fingerprintDir/median" && mkdir -p $fingerprintDir

# set to scale fingerprint to 98% connectivity strength or not
flgScaleGroup=0 # do not scale group-level fingerprints
flgScaleFirstLevel=1 # do scale first-level (run/sess/subj) fingerprints

# retrieve the instruction file
instructFile=$anaDir/instruct/instructExtractFingerprint${suffixValidate/./_}.txt
[[ ! -s $instructFile ]] && echo "" && >&2 printf "\nError: no valid instruction file found at:\n%s\n\n" $instructFile && exit 1
[[ $(tail -c1 $instructFile | wc -l) -le 0 ]] && echo "" >> $instructFile

# retrieve the first-level instructions
if [[ $flgLevel =~ RUN ]] || [[ $flgLevel =~ SESS ]] || [[ $flgLevel =~ SUBJ ]] ; then
  intructFirstLevelFile=$anaDir/instruct/instructExtractFingerprintFirstLevel${suffixValidate/./_}.txt
  [[ ! -s $intructFirstLevelFile ]] && echo "" && >&2 printf "\nError: no valid first-level instruction file found at:\n%s\n\n" $intructFirstLevelFile && exit 1
fi


# start a timer
SECONDS=0


# ----------------------------------- #
# EXTRACTING CONNECTIVITY FINGERPRINT
# ----------------------------------- #
echo ""
echo "EXTRACTING FINGERPRINT"

# create a temporary directory to store the ROIs and intermediate results
tmpDir=$(mktemp -d "$anaDir/tmp.fingerprint.XXXXXXXXXX")

# extracting ROIs
echo "  extracting target ROIs from full set"

# identify all the seed and target ROIs
roiList=$(cut -d' ' -f3- $instructFile | tr ' ' '\n' | sort -f | uniq)
roiMapList=$(wb_command -file-information $anaDir/roi/roi.dscalar.nii -only-map-names)

# loop over ROIs
for roiName in $roiList ; do

  # loop over hemispheres
  for hemi in bilat left right ; do

    # find the column index
    idxCol=$(echo "$roiMapList" | awk '($1 == "'$roiName.$hemi'"){print NR; exit}')
    [[ -z $idxCol ]] && >&2 echo "ROI \"$roiName.$hemi\" not found in file \"$anaDir/roi/roi.dscalar.nii\"" && exit 1

    # retrieve the ROI mask
    wb_command -cifti-merge $tmpDir/roi.$roiName.$hemi.dscalar.nii -cifti $anaDir/roi/roi.dscalar.nii -column $idxCol
    wb_command -cifti-restrict-dense-map $tmpDir/roi.$roiName.$hemi.dscalar.nii COLUMN $tmpDir/roi.$roiName.$hemi.dscalar.nii -cifti-roi $MRCATDIR/data/macaque/F99/surf/cortex_subcort.roi.F99_10k.dscalar.nii

  done # for hemi in left right ; do

done # for roiName in $roiList ; do


# identify all the FUN sites
echo "  extracting fingerprints per FUN site"
siteList=$(awk '{print $1}' $instructFile | sort -f | uniq)

# count the maximum number of targets
nTargetMax=$(awk '{if(NF>n) {n=NF}} END {print n-2}' $instructFile)


# loop over sites
for siteName in $siteList ; do
  echo "    $siteName"

  # print a temporary instructFile
  awk '($1 == "'$siteName'"){print $0}' $instructFile > $tmpDir/instruct.txt

  # by default, don't do scaling, unless specifically requested
  flgScale=0

  # initialise analysis levels
  anaLevelList=""
  # general structure: anaLevelList+="sbcaData@fingerprintFile@${flgScale}"

  # group analysis
  if [[ $flgLevel =~ _GROUP_ ]] ; then
    workDir=$fingerprintDir/group
    mkdir -p $workDir

    # specify SBCA data and fingerprint file
    sbcaData=$anaDir/sbca/group/${siteName}${suffixConn}.sbca.dscalar.nii
    fingerprintFile=$workDir/$siteName.txt
    anaLevelList+=" ${sbcaData}@${fingerprintFile}@${flgScaleGroup}"
    [[ $flgScale -eq 0 ]] && flgScale=$flgScaleGroup
  fi

  # subject analysis
  if [[ $flgLevel =~ _SUBJ_ ]] ; then
    workDir=$fingerprintDir/subj
    mkdir -p $workDir

    # extract subject names from instruction file
    subjNameList=$(awk '($1 == "'$siteName'")&&($2 == "subj"){print $0}' $intructFirstLevelFile | cut -d' ' -f3-)
    for subjName in $subjNameList ; do
      # specify SBCA data and fingerprint file for each subject individually
      sbcaData=$anaDir/sbca/subj/${siteName}.${subjName}${suffixConn}.sbca.dscalar.nii
      fingerprintFile=$workDir/$siteName.${subjName}.txt
      anaLevelList+=" ${sbcaData}@${fingerprintFile}@${flgScaleFirstLevel}"
    done
    [[ $flgScale -eq 0 ]] && flgScale=$flgScaleFirstLevel
  fi

  # session analysis
  if [[ $flgLevel =~ _SESS_ ]] ; then
    workDir=$fingerprintDir/sess
    mkdir -p $workDir

    # extract session names from instruction file, specified as "subjectName.scanID"
    sessNameList=$(awk '($1 == "'$siteName'")&&($2 == "sess"){print $0}' $intructFirstLevelFile | cut -d' ' -f3-)
    for sessName in $sessNameList ; do
      # specify SBCA data and fingerprint file for each session individually
      sbcaData=$anaDir/sbca/sess/${siteName}.${sessName}${suffixConn}.sbca.dscalar.nii
      fingerprintFile=$workDir/$siteName.${sessName}.txt
      anaLevelList+=" ${sbcaData}@${fingerprintFile}@${flgScaleFirstLevel}"
    done
    [[ $flgScale -eq 0 ]] && flgScale=$flgScaleFirstLevel
  fi

  # run analysis (across subjects, not per subject)
  if [[ $flgLevel =~ _RUN_ ]] ; then
    workDir=$fingerprintDir/run
    mkdir -p $workDir

    # extract run names from instruction file, specified as "run[idx]"
    runNameList=$(awk '($1 == "'$siteName'")&&($2 == "run"){print $0}' $intructFirstLevelFile | cut -d' ' -f3-)
    for runName in $runNameList ; do
      # specify SBCA data and fingerprint file for each run individually
      sbcaData=$anaDir/sbca/run/${siteName}.${runName}${suffixConn}.sbca.dscalar.nii
      fingerprintFile=$workDir/$siteName.${runName}.txt
      anaLevelList+=" ${sbcaData}@${fingerprintFile}@${flgScaleFirstLevel}"
    done
    [[ $flgScale -eq 0 ]] && flgScale=$flgScaleFirstLevel
  fi

  # subject-run analysis (per subject, not across subjects)
  if [[ $flgLevel =~ _SUBJRUN_ ]] ; then
    workDir=$fingerprintDir/subjrun
    mkdir -p $workDir

    # extract subjrun names from instruction file, specified as "subjectName.run[idx]"
    subjrunNameList=$(awk '($1 == "'$siteName'")&&($2 == "subjrun"){print $0}' $intructFirstLevelFile | cut -d' ' -f3-)
    for subjrunName in $subjrunNameList ; do
      # specify SBCA data and fingerprint file for each subject-run individually
      sbcaData=$anaDir/sbca/subjrun/${siteName}.${subjrunName}${suffixConn}.sbca.dscalar.nii
      fingerprintFile=$workDir/$siteName.${subjrunName}.txt
      anaLevelList+=" ${sbcaData}@${fingerprintFile}@${flgScaleFirstLevel}"
    done
    [[ $flgScale -eq 0 ]] && flgScale=$flgScaleFirstLevel
  fi

  # session-run analysis (per session, not across sessions)
  if [[ $flgLevel =~ _SESSRUN_ ]] ; then
    workDir=$fingerprintDir/sessrun
    mkdir -p $workDir

    # extract sessrun names from instruction file, specified as "subjectName.sessName.run[idx]"
    sessrunNameList=$(awk '($1 == "'$siteName'")&&($2 == "sessrun"){print $0}' $intructFirstLevelFile | cut -d' ' -f3-)
    for sessrunName in $sessrunNameList ; do
      # specify SBCA data and fingerprint file for each session-run individually
      sbcaData=$anaDir/sbca/sessrun/${siteName}.${sessrunName}${suffixConn}.sbca.dscalar.nii
      fingerprintFile=$workDir/$siteName.${sessrunName}.txt
      anaLevelList+=" ${sbcaData}@${fingerprintFile}@${flgScaleFirstLevel}"
    done
    [[ $flgScale -eq 0 ]] && flgScale=$flgScaleFirstLevel
  fi

  # print the 98-percentile scaling factors for all maps in this dataset
  if [[ $flgScale -eq 1 ]] ; then
    wb_command -cifti-math "(data>0)" $tmpDir/roi.pos.dscalar.nii -var "data" $sbcaData > /dev/null
    wb_command -cifti-stats $sbcaData -percentile 98 -roi $tmpDir/roi.pos.dscalar.nii -match-maps > $tmpDir/scale.$siteName.txt
  fi


  # loop over analysis levels
  nAnaLevel=$(echo $anaLevelList | wc -w)
  for anaLevel in $anaLevelList ; do

    # extract the SBCA data and the fingerprint file name
    sbcaData=$(echo $anaLevel | cut -d@ -f1)
    fingerprintFile=$(echo $anaLevel | cut -d@ -f2)
    flgScale=$(echo $anaLevel | cut -d@ -f3)

    # report
    anaLevelReport=$(basename ${fingerprintFile%%.txt})
    anaLevelReport=$(echo $anaLevelReport | sed "s@^$siteName@@" | sed "s@^.@@")
    [[ -z $anaLevelReport ]] && anaLevelReport="group"
    [[ $nAnaLevel -gt 1 ]] && echo "      $anaLevelReport"

    # initialise an empty fingerprint file
    > $fingerprintFile

    # compile a list of connectivity maps available for this site
    mapList=$(wb_command -file-information $sbcaData -only-map-names)

    # loop over seeds
    while read -r siteNameDummy seedName targetList ; do

      # append the hemisphere suffixes for the targets
      targetListHemi=$(echo $targetList | tr " " "\n" | awk '{print $1 ".bilat " $1 ".left " $1 ".right"}' | tr "\n" " ")

      # if the current targetList is shorter than the longest, append with dummy targets
      nTargetHemi=$(echo $targetListHemi | awk '{print NF}')
      nDummy=$(echo $nTargetMax $nTargetHemi | awk '{print (3*$1)-$2 }')
      [[ $nDummy -gt 0 ]] && targetListHemi+=$(printf ' -%.0s' $(seq 1 $nDummy))

      # write header line (repeated for each seed)
      printf "%s_seed" $seedName >> $fingerprintFile
      printf " %s" $targetListHemi >> $fingerprintFile
      printf "\n" >> $fingerprintFile

      # loop over hemispheres of the seed
      for hemi in bilat left right ; do
        # write seed name with hemisphere suffix to the report
        printf "%s " ${seedName}_${hemi} >> $fingerprintFile

        # find the right column in the seed-based connectivity cifti file
        idxCol=$(echo "$mapList" | awk '($1 == "'$seedName.$hemi'"){print NR; exit}')

        # retrieve the scaling factor
        if [[ $flgScale -eq 1 ]] ; then
          scaleFact=$(awk '(FNR == "'$idxCol'"){print $1}' $tmpDir/scale.$siteName.txt)
        else
          # do not scale
          scaleFact=1
        fi

        # loop over targets
        fingerprintData=""
        for targetName in $targetListHemi ; do
          [[ $targetName == "-" ]] && fingerprintData+="nan " && continue
          # extract the data from the seed ROI and write to report
          fingerprintData+=$(wb_command -cifti-stats $sbcaData -column $idxCol -reduce $flgSummaryStat -roi $tmpDir/roi.$targetName.dscalar.nii | awk '{print $1 / "'$scaleFact'"}')
          fingerprintData+=" "
        done

        # the fingerprint data is printed to the report using "echo" to automatically collapse redundant white-space
        echo $fingerprintData >> $fingerprintFile

      done

    done < $tmpDir/instruct.txt

  done

done


# clean-up
rm -r $tmpDir

echo ""
echo "DONE"
echo "  seconds elapsed: $SECONDS"
echo ""
