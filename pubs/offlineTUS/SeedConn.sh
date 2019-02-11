#!/usr/bin/env bash
umask u+rw,g+rw # give group read/write permissions to all new files
set -e    # stop immediately on error

# TODO: if for some SUBJ/SESS one run is acquired, but for others multiple, only
# the runs with multiple end up in the SUBJRUN/SESSRUN folder. You could
# consider to copy the SUBJ/SESS SBCA file to the SUBJRUN/SESSRUN folder.

# ------------------- #
# GENERAL DEFINITIONS
# ------------------- #
source $MRCATDIR/setupMrCat.sh
studyDir="/Volumes/rsfMRI/anaesthesia"
procDir="$studyDir/proc"
anaDir="$studyDir/analysis"
mkdir -p $anaDir/sbca

# try to retrieve the dataset and analysis configuration, or opt for defaults
[[ -f $anaDir/instruct/sourceConfig.sh ]] && source $anaDir/instruct/sourceConfig.sh
[[ -z $suffixClean ]] && suffixClean="WMCSF"
[[ -z $suffixTS ]] && suffixTS="_hpbs_clean${suffixClean}_lp.smooth"
[[ -z $suffixConn ]] && suffixConn=".clean${suffixClean}"
[[ -z $flgValidate ]] && flgValidate=0 && suffixValidate=""
[[ -z $flgCapStat ]] && flgCapStat=1
[[ -z $flgLevel ]] && flgLevel="SUBJRUN_SUBJ_RUN_GROUP" # specify the analysis level: SUBJRUN, RUN, SESS, SUBJ, GROUP, or any combination (RUN_SUBJ_GROUP)
[[ -z $runList ]] && runList="run1 run2 run3" # specify which runs to consider for the RUN level analysis
flgLevel="_${flgLevel}_" # pad with lines to make regular expressions easier

# retrieve the instruction file
instructFile=$anaDir/instruct/instructSeedConn${suffixValidate/./_}.txt
[[ ! -s $instructFile ]] && echo "" && >&2 printf "\nError: no valid instruction file found at:\n%s\n\n" $instructFile && exit 1
[[ $(tail -c1 $instructFile | wc -l) -le 0 ]] && echo "" >> $instructFile

# find the first-level instructions
if [[ $flgLevel =~ SESS ]] || [[ $flgLevel =~ SUBJ ]] ; then
  intructFirstLevelFile=$anaDir/instruct/instructSeedConnFirstLevel${suffixValidate/./_}.txt
  [[ ! -s $intructFirstLevelFile ]] && echo "" && >&2 printf "\nError: no valid first-level instruction file found at:\n%s\n\n" $intructFirstLevelFile && exit 1
fi


# start a timer
SECONDS=0


# -------------------------------- #
# SEED-BASED CONNECTIVITY ANALYSIS
# -------------------------------- #
echo ""
echo "PERFORMING SEED-BASED CONNECTIVITY ANALYSIS"
echo "time-series input suffix:   $suffixTS"
echo "connectivity output suffix: $suffixConn"
echo ""

# create a temporary directory to store the ROIs and intermediate results
tmpDir=$(mktemp -d "$anaDir/tmp.seedconn.XXXXXXXXXX")

# extracting ROIs
echo "  extracting seed ROIs from full set"
mkdir -p $tmpDir/roi

# identify all the seed and target ROIs
roiList=$(cut -d' ' -f2- $instructFile | tr ' ' '\n' | sort -f | uniq)
roiMapList=$(wb_command -file-information $anaDir/roi/roi.dscalar.nii -only-map-names)

# loop over ROIs
for roiName in $roiList ; do

  # loop over hemispheres
  for hemi in left right ; do

    # find the column index
    idxCol=$(echo "$roiMapList" | awk '($1 == "'$roiName.$hemi'"){print NR; exit}')
    [[ -z $idxCol ]] && >&2 echo "ROI \"$roiName.$hemi\" not found in file \"$anaDir/roi/roi.dscalar.nii\"" && exit 1

    # retrieve the ROI mask
    wb_command -cifti-merge $tmpDir/roi/$roiName.$hemi.dscalar.nii -cifti $anaDir/roi/roi.dscalar.nii -column $idxCol
    wb_command -cifti-restrict-dense-map $tmpDir/roi/$roiName.$hemi.dscalar.nii COLUMN $tmpDir/roi/$roiName.$hemi.dscalar.nii -cifti-roi $MRCATDIR/data/macaque/F99/surf/cortex_subcort.roi.F99_10k.dscalar.nii

  done # for hemi in left right ; do

done # for roiName in $roiList ; do


# loop over FUN sites
while read -r siteName roiList ; do
  echo ""
  echo "  FUN site: $siteName"
  mkdir -p $tmpDir/$siteName

  # append the hemisphere suffixes for the ROIs
  roiListHemi=$(echo $(printf ' %s.left' $roiList) $(printf ' %s.right' $roiList))

  # creating a command to merge all selected ROIs together
  cmdMerge=""
  for roiName in $roiListHemi ; do
    cmdMerge+=" -cifti $tmpDir/roi/$roiName.dscalar.nii"
  done

  # merge the site-specific ROIs back together
  wb_command -cifti-merge $tmpDir/$siteName/roi.combined.dscalar.nii $cmdMerge
  wb_command -cifti-reduce $tmpDir/$siteName/roi.combined.dscalar.nii MAX $tmpDir/$siteName/roi.combined.dscalar.nii

  # set up a list of data files to process: group-level + subject-level
  datasetList=""

  # specify where the GROUP whole-brain time-series can be found and the ROI-averaged data will be stored
  if [[ $flgLevel =~ _GROUP_ ]] ; then
    workDir=$anaDir/sbca/group
    mkdir -p $workDir

    siteTimeSeriesData=$procDir/$siteName/func${suffixTS}${suffixValidate}.F99_10k.dtseries.nii
    seedConn=$workDir/${siteName}${suffixConn}.sbca.dscalar.nii
    datasetList+=" $siteTimeSeriesData@$seedConn"
  fi

  # specify where the SESS whole-brain time-series can be found and the ROI-averaged data will be stored
  if [[ $flgLevel =~ _SESS_ ]] ; then
    workDir=$anaDir/sbca/sess
    mkdir -p $workDir

    # extract site-specific information from the subject-level instruction file
    awk '($3 == "'$siteName'"){print $0}' $intructFirstLevelFile > $tmpDir/$siteName/instructSess.txt

    # loop over sessions
    while read -r scanID monkey siteNameDummy runSet coord ; do
      # ignore listings for multiple sessions
      [[ $scanID == "all" ]] && continue
      # specify session data
      siteTimeSeriesData=$procDir/$siteName/$monkey/$scanID/functional/func${suffixTS}.F99_10k.dtseries.nii
      seedConn=$workDir/$siteName.${monkey}.${scanID}${suffixConn}.sbca.dscalar.nii
      datasetList+=" $siteTimeSeriesData@$seedConn"
    done < $tmpDir/$siteName/instructSess.txt  # read instructions line by line

  fi

  # specify where the SESS/SUBJ whole-brain time-series can be found and the ROI-averaged data will be stored
  if [[ $flgLevel =~ _SUBJ_ ]] ; then
    workDir=$anaDir/sbca/subj
    mkdir -p $workDir

    # extract site-specific information from the subject-level instruction file
    awk '($3 == "'$siteName'"){print $0}' $intructFirstLevelFile > $tmpDir/$siteName/instructSess.txt

    # check how many times the same subject is listed for this site
    subjList=$(awk '{print $2}' $tmpDir/$siteName/instructSess.txt)
    subjUniqueList=$(echo "$subjList" | sort | uniq)

    # replace the sessionID of subject listings with multiple sessions to "all"
    > $tmpDir/$siteName/instructSubj.txt
    for subjName in $subjUniqueList ; do
      instructSubj=$(awk '($2 == "'$subjName'"){print $0}' $tmpDir/$siteName/instructSess.txt)
      if [[ $(echo "$instructSubj" | wc -l) -lt 2 ]] ; then
        # simply copy single session listings
        echo "$instructSubj" >> $tmpDir/$siteName/instructSubj.txt
      else
        # extract only the entry listed as "all"
        instructSubj=$(echo "$instructSubj" | awk '($1 == "all"){; print $0}')
        # give an error when not found, or write to the subject instructions
        if [[ -z $instructSubj ]] ; then
          >&2 printf '\nError: multiple sessions specified for a single subject but none with the sessionID / scanID "all"\n\n'
          >&2 cat $tmpDir/$siteName/instructSess.txt
          rm -rf $tmpDir
          exit 1
        else
          echo "$instructSubj" >> $tmpDir/$siteName/instructSubj.txt
        fi
      fi
    done

    # loop over subjects
    while read -r scanID monkey siteNameDummy runSet coord ; do
      if [[ $scanID == "all" ]] ; then
        siteTimeSeriesData=$procDir/$siteName/$monkey/func${suffixTS}.F99_10k.dtseries.nii
      else
        siteTimeSeriesData=$procDir/$siteName/$monkey/$scanID/functional/func${suffixTS}.F99_10k.dtseries.nii
      fi
      seedConn=$workDir/$siteName.${monkey}${suffixConn}.sbca.dscalar.nii
      datasetList+=" $siteTimeSeriesData@$seedConn"
    done < $tmpDir/$siteName/instructSubj.txt  # read instructions line by line

  fi

  # specify where the RUN whole-brain time-series can be found and the ROI-averaged data will be stored
  if [[ $flgLevel =~ _RUN_ ]] ; then
    mkdir -p $anaDir/sbca/run

    # loop over runs
    for run in $runList ; do
      siteTimeSeriesData=$procDir/$siteName/func_${run}${suffixTS}${suffixValidate}.F99_10k.dtseries.nii
      # skip if this dataset does not exist
      [[ ! -f $siteTimeSeriesData ]] && continue
      # specify the name of the SBCA file
      seedConn=$anaDir/sbca/run/$siteName.${run}${suffixConn}.sbca.dscalar.nii
      datasetList+=" $siteTimeSeriesData@$seedConn"
    done

  fi

  # check for impossible combinations of analysis levels
  if [[ $flgLevel =~ _SUBJRUN_ ]] && [[ $flgLevel =~ _SESSRUN_ ]] ; then
    >&2 printf '\nError: It is currently not supported to run SUBJRUN and SESSRUN analyses together.\nPlease consider to specify only SUBJRUN or SESSRUN level analysis.\n\n'
    rm -rf $tmpDir
    exit 1
  fi

  # specify where the SUBJRUN whole-brain time-series can be found and the ROI-averaged data will be stored
  if [[ $flgLevel =~ _SUBJRUN_ ]] || [[ $flgLevel =~ _SESSRUN_ ]] ; then
    [[ $flgLevel =~ _SUBJRUN_ ]] && workDir=$anaDir/sbca/subjrun || workDir=$anaDir/sbca/sessrun
    mkdir -p $workDir

    # extract site-specific information from the subject-level instruction file
    awk '($3 == "'$siteName'"){print $0}' $intructFirstLevelFile > $tmpDir/$siteName/instructSubjSess.txt

    # for subject-run analysis only
    if [[ $flgLevel =~ _SUBJRUN_ ]] ; then

      # check how many times the same subject is listed for this site
      subjList=$(awk '{print $2}' $tmpDir/$siteName/instructSubjSess.txt)
      nSubj=$(echo "$subjList" | wc -l)
      nSubjUnique=$(echo "$subjList" | sort | uniq | wc -l)

      # give an error when a single subject is listed with more than one session
      if [[ $nSubj -gt $nSubjUnique ]] ; then
        >&2 printf '\nError: multiple sessions specified for a single subject while trying to run a SUBJRUN analysis.\nPlease consider to specify only a single session per subject, or running a SESSRUN level analysis.\n\n'
        >&2 cat $tmpDir/$siteName/instructSubjSess.txt
        rm -rf $tmpDir
        exit 1
      fi

    fi

    # loop over subjects/sessions
    while read -r scanID monkey siteNameDummy runSet coord ; do

      # loop over runs
      for run in $runList ; do
        siteTimeSeriesData=$procDir/$siteName/$monkey/$scanID/functional/${run}/func_${run}${suffixTS}.F99_10k.dtseries.nii
        # if this dataset does not exist, assume that only a single run was acquired
        if [[ ! -f $siteTimeSeriesData ]] && [[ $run == "run1" ]] ; then
          siteTimeSeriesData=$procDir/$siteName/$monkey/$scanID/functional/func${suffixTS}.F99_10k.dtseries.nii
        fi
        # if this dataset still does not exist, skip it
        [[ ! -f $siteTimeSeriesData ]] && continue
        # specify the name of the SBCA file based on the analysis type
        if [[ $flgLevel =~ _SUBJRUN_ ]] ; then
          seedConn=$workDir/$siteName.${monkey}.${run}${suffixConn}.sbca.dscalar.nii
        else
          seedConn=$workDir/$siteName.${monkey}.${scanID}.${run}${suffixConn}.sbca.dscalar.nii
        fi
        datasetList+=" $siteTimeSeriesData@$seedConn"
      done

    done < $tmpDir/$siteName/instructSubjSess.txt  # read instructions line by line

  fi


  # process the datasets one-by-one
  for dataset in $datasetList ; do
    siteTimeSeriesData=$(echo $dataset | cut -d'@' -f1)
    seedConn=$(echo $dataset | cut -d'@' -f2)
    echo "    processing: $(basename $seedConn)"


    # extracting whole-brain connectivity for all ROIs in one go
    echo "      performing cross-correlation"
    dconn=$tmpDir/$siteName/rfMRI.dconn.nii

    # run cross-corr from ROI to all
    wb_command -cifti-correlation $siteTimeSeriesData $dconn -roi-override -cifti-roi $tmpDir/$siteName/roi.combined.dscalar.nii -fisher-z

    # make sure the medial wall is excluded
    wb_command -cifti-restrict-dense-map $dconn ROW $dconn -cifti-roi $MRCATDIR/data/macaque/F99/surf/cortex_subcort.roi.F99_10k.dscalar.nii

    # limit the values from -2 to 2 (shh, be silent)
    if [[ $flgCapStat -eq 1 ]] ; then
      wb_command -cifti-math "clamp(data,(-2),2)" $dconn -fixnan 0 -var "data" $dconn > /dev/null
    fi


    # average the connectivity profiles within each ROI
    echo "      averaging connectivity per seed"
    cmdUnilat=""
    for roiName in $roiListHemi ; do

      # restrict the seed ROI COLUMNs to match the dconn ROWs
      wb_command -cifti-restrict-dense-map $tmpDir/roi/$roiName.dscalar.nii COLUMN $tmpDir/$siteName/$roiName.dscalar.nii -cifti-roi $tmpDir/$siteName/roi.combined.dscalar.nii

      # restrict the dconn COLUMNs to the seed ROI
      wb_command -cifti-restrict-dense-map $dconn COLUMN $tmpDir/$siteName/seed.dconn.nii -cifti-roi $tmpDir/$siteName/$roiName.dscalar.nii

      # average over the vertices in the seed ROI
      wb_command -cifti-reduce $tmpDir/$siteName/seed.dconn.nii MEAN $tmpDir/$siteName/seed.dconn.nii -direction COLUMN
      wb_command -cifti-change-mapping $tmpDir/$siteName/seed.dconn.nii COLUMN $tmpDir/$siteName/$roiName.dscalar.nii -scalar
      wb_command -cifti-transpose $tmpDir/$siteName/$roiName.dscalar.nii $tmpDir/$siteName/$roiName.dscalar.nii

      # aggregate command to merge
      cmdUnilat+=" -cifti $tmpDir/$siteName/$roiName.dscalar.nii"

    done


    # average the ROI connectivity profiles across hemispheres
    echo "      averaging connectivity across hemispheres"

    # loop over bilateral ROIs
    cmdBilat=""
    for roiName in $roiList ; do
      #echo "  $roiName"

      # average the left and right hemispheres
      wb_command -cifti-average $tmpDir/$siteName/$roiName.bilat.dscalar.nii -cifti $tmpDir/$siteName/$roiName.left.dscalar.nii -cifti $tmpDir/$siteName/$roiName.right.dscalar.nii

      # aggregate command to merge
      cmdBilat+=" -cifti $tmpDir/$siteName/$roiName.bilat.dscalar.nii"

    done

    # combining the unilateral and bilateral seeds in one file
    wb_command -cifti-merge $seedConn $cmdUnilat $cmdBilat

    # add sensible names to the connectivity maps
    echo $roiListHemi $(printf ' %s.bilat' $roiList) | tr " " "\n" > $tmpDir/$siteName/name.all.txt
    wb_command -set-map-names $seedConn -name-file $tmpDir/$siteName/name.all.txt

    # reorder ROIs alphabetically
    nl $tmpDir/$siteName/name.all.txt | sort -f -k 2 | awk '{print $1}' > $tmpDir/$siteName/reorder.txt
    wb_command -cifti-reorder $seedConn ROW $tmpDir/$siteName/reorder.txt $seedConn

  done

done < $instructFile


# clean-up
rm -r $tmpDir

echo ""
echo "DONE"
echo "  seconds elapsed: $SECONDS"
echo ""
