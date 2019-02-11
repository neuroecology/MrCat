#!/usr/bin/env bash
umask u+rw,g+rw # give group read/write permissions to all new files
set -e    # stop immediately on error

# when input arguments are provided, use these rather than the instruction file
[[ $# -gt 0 ]] && instruct="$*" || instruct=""

# ------------------- #
# GENERAL DEFINITIONS
# ------------------- #
source $MRCATDIR/setupMrCat.sh
studyDir="/Volumes/rsfMRI/anaesthesia"
procDir="$studyDir/proc"
anaDir="$studyDir/analysis"
mkdir -p $anaDir/map

# try to retrieve the dataset suffices, or opt for defaults
[[ -f $anaDir/instruct/sourceConfig.sh ]] && source $anaDir/instruct/sourceConfig.sh
[[ -z $suffixClean ]] && suffixClean="WMCSF"
[[ -z $suffixTS ]] && suffixTS="_hpbs_clean${suffixClean}_lp.smooth"
[[ -z $suffixConn ]] && suffixConn=".clean${suffixClean}"
[[ -z $flgValidate ]] && flgValidate=0 && suffixValidate=""
[[ -z $flgLevel ]] && flgLevel="SUBJRUN_SUBJ_RUN_GROUP" # specify the analysis level: SUBJRUN, RUN, SESS, SUBJ, GROUP, or any combination (RUN_SUBJ_GROUP)
flgLevel="_${flgLevel}_" # pad with lines to make regular expressions easier

# create a temporary directory to store intermediate results
tmpDir=$(mktemp -d "$anaDir/tmp.quantifyTS.XXXXXXXXXX")

# set up an instruction file
instructFileTmp=$tmpDir/instructQuantifyTimeSeries.txt
if [[ -n $instruct ]] ; then

  echo $instruct > $instructFileTmp

else

  # retrieve the instruction file
  instructFile=$anaDir/instruct/instructQuantifyTimeSeries${suffixValidate/./_}.txt
  [[ ! -s $instructFile ]] && echo "" && >&2 printf "\nError: no valid instruction file found at:\n%s\n\n" $instructFile && exit 1
  [[ $(tail -c1 $instructFile | wc -l) -le 0 ]] && echo "" >> $instructFile

  # copy to the temporary instruction file
  cp $instructFile $instructFileTmp

fi

# retrieve the first-level instructions
if [[ $flgLevel =~ SESS ]] || [[ $flgLevel =~ SUBJ ]] ; then
  intructFirstLevelFile=$anaDir/instruct/instructSeedConnFirstLevel${suffixValidate/./_}.txt
  [[ ! -s $intructFirstLevelFile ]] && echo "" && >&2 printf "\nError: no valid first-level instruction file found at:\n%s\n\n" $intructFirstLevelFile && exit 1
fi

# start a timer
SECONDS=0


# ----------------------- #
# QUANTIFYING TIME-SERIES
# ----------------------- #
echo ""
echo "QUANTIFYING TIME-SERIES"


# loop over FUN sites
while read -r siteName metricList; do
  echo ""
  echo "  FUN site: $siteName"
  mkdir -p $tmpDir/$siteName

  # examples of useful metrics
  #metricList="stdev variance"

  # anything related to the mean might not be very informative,
  # as many timeseries will have been de-meaned explicitely
  #metricList="mean tsnr cov"

  # loop over metrics to quantify the time-series
  for metricName in $metricList ; do

    # change metric name to capitals as an operation for wb_command -cifti-reduce
    cmdReduce=$(echo $metricName | tr '[:lower:]' '[:upper:]')

    # by default use the sample standard deviation (N-1 denominator)
    [[ $cmdReduce == "STDEV" ]]  && cmdReduce="SAMPSTDEV"

    # initialise analysis levels
    datasetList=""
    # general structure: datasetList+="siteTimeSeriesData@mapFileName"

    # group analysis
    if [[ $flgLevel =~ _GROUP_ ]] ; then
      workDir=$anaDir/map/group
      mkdir -p $workDir

      # specify where the whole-brain time-series can be found and the output map will be stored
      siteTimeSeriesData=$procDir/$siteName/func${suffixTS}${suffixValidate}.F99_10k.dtseries.nii
      mapFileName=$workDir/${siteName}${suffixConn}.$metricName.dscalar.nii
      datasetList+=" $siteTimeSeriesData@$mapFileName"
    fi

    # specify where the SESS whole-brain time-series can be found and the ROI-averaged data will be stored
    if [[ $flgLevel =~ _SESS_ ]] ; then
      workDir=$anaDir/map/sess
      mkdir -p $workDir

      # extract site-specific information from the subject-level instruction file
      awk '($3 == "'$siteName'"){print $0}' $intructFirstLevelFile > $tmpDir/$siteName/instructSess.txt

      # loop over sessions
      while read -r scanID monkey siteNameDummy runSet coord ; do
        # ignore listings for multiple sessions
        [[ $scanID == "all" ]] && continue
        # specify session data
        siteTimeSeriesData=$procDir/$siteName/$monkey/$scanID/functional/func${suffixTS}.F99_10k.dtseries.nii
        mapFileName=$workDir/$siteName.${monkey}.${scanID}${suffixConn}.$metricName.dscalar.nii
        datasetList+=" $siteTimeSeriesData@$mapFileName"
      done < $tmpDir/$siteName/instructSess.txt  # read instructions line by line

    fi

    # specify where the SESS/SUBJ whole-brain time-series can be found and the ROI-averaged data will be stored
    if [[ $flgLevel =~ _SUBJ_ ]] ; then
      workDir=$anaDir/map/subj
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
        mapFileName=$workDir/$siteName.${monkey}${suffixConn}.$metricName.dscalar.nii
        datasetList+=" $siteTimeSeriesData@$mapFileName"
      done < $tmpDir/$siteName/instructSubj.txt  # read instructions line by line

    fi

    # specify where the RUN whole-brain time-series can be found and the ROI-averaged data will be stored
    if [[ $flgLevel =~ _RUN_ ]] ; then
      mkdir -p $anaDir/map/run

      # loop over runs
      for run in $runList ; do
        siteTimeSeriesData=$procDir/$siteName/func_${run}${suffixTS}${suffixValidate}.F99_10k.dtseries.nii
        # skip if this dataset does not exist
        [[ ! -f $siteTimeSeriesData ]] && continue
        # specify the name of the SBCA file
        mapFileName=$anaDir/map/run/$siteName.${run}${suffixConn}.$metricName.dscalar.nii
        datasetList+=" $siteTimeSeriesData@$mapFileName"
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
      [[ $flgLevel =~ _SUBJRUN_ ]] && workDir=$anaDir/map/subjrun || workDir=$anaDir/map/sessrun
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
          if [[ ! -f $siteTimeSeriesData ]] ; then
            siteTimeSeriesData=$procDir/$siteName/$monkey/$scanID/functional/func${suffixTS}.F99_10k.dtseries.nii
          fi
          # if this dataset still does not exist, skip it
          [[ ! -f $siteTimeSeriesData ]] && continue
          # specify the name of the SBCA file based on the analysis type
          if [[ $flgLevel =~ _SUBJRUN_ ]] ; then
            mapFileName=$workDir/$siteName.${monkey}.${run}${suffixConn}.$metricName.dscalar.nii
          else
            mapFileName=$workDir/$siteName.${monkey}.${scanID}.${run}${suffixConn}.$metricName.dscalar.nii
          fi
          datasetList+=" $siteTimeSeriesData@$mapFileName"
        done

      done < $tmpDir/$siteName/instructSubjSess.txt  # read instructions line by line

    fi



    # loop over analysis levels
    for dataset in $datasetList ; do

      # extract the timeseries data and the map file name
      siteTimeSeriesData=$(echo $dataset | cut -d@ -f1)
      mapFileName=$(echo $dataset | cut -d@ -f2)

      # quantifying the range requires a few extra steps...
      if [[ $cmdReduce == "RANGE" ]] ; then

        # quantify the minimum and maximum values
        wb_command -cifti-reduce $siteTimeSeriesData MIN $tmpDir/$siteName/min.dscalar.nii -direction ROW -only-numeric
        wb_command -cifti-reduce $siteTimeSeriesData MAX $tmpDir/$siteName/max.dscalar.nii -direction ROW -only-numeric

        # calculate the range by subtracting the minimum from the maximum
        wb_command -cifti-math "(upper-lower)" $mapFileName -fixnan 0 -var "upper" $tmpDir/$siteName/max.dscalar.nii -var "lower" $tmpDir/$siteName/min.dscalar.nii > /dev/null

      else

        # quantifying standard metrics
        wb_command -cifti-reduce $siteTimeSeriesData $cmdReduce $mapFileName -direction ROW -only-numeric

      fi

      # make sure the medial wall is excluded
      wb_command -cifti-restrict-dense-map $mapFileName COLUMN $mapFileName -cifti-roi $MRCATDIR/data/macaque/F99/surf/cortex_subcort.roi.F99_10k.dscalar.nii

    done

  done

done < $instructFileTmp


# clean-up
rm -r $tmpDir

echo ""
echo "DONE"
echo "  seconds elapsed: $SECONDS"
echo ""
