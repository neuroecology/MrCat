#!/usr/bin/env bash
umask u+rw,g+rw # give group read/write permissions to all new files
set -e    # stop immediately on error

# TODO: perhaps the structural should be specified in the instructFile
# for now, I'm simply taking the latest

# retrieve input argument to find correct instructions
instructDir="$1"

# ------------------- #
# GENERAL DEFINITIONS
# ------------------- #
source $MRCATDIR/setupMrCat.sh
studyDir="/Volumes/rsfMRI/anaesthesia/proc"
structRootDir="/Volumes/rsfMRI/structural/proc"

# retrieve the instruction file
instructFile=$studyDir/$instructDir/instruct/instructProcFunc.txt
[[ ! -s $instructFile ]] && echo "" && >&2 printf "\nError: no valid instruction file found at:\n%s\n\n" $instructFile && exit 1
[[ $(tail -c1 $instructFile | wc -l) -le 0 ]] && echo "" >> $instructFile

# define the outlier instruction file
instructOutlierFile=$studyDir/$instructDir/instruct/instructOutlier.txt

# start a timer
SECONDS=0


# ------------------------------ #
# PROCESS FUNCTIONAL IMAGES
# ------------------------------ #
echo ""
echo "PROCESS FUNCTIONAL IMAGES"

# print out the instructions
echo "instructions:"
cat $instructFile
echo ""

# loop over instructions
echo "working on:"
while read -r scanID monkey site runSet coord ; do
  printf "  monkey: %s\n" "$monkey"
  printf "    scan: %s (%s)\n" "$scanID" "$site"
  funcDir=$studyDir/$site/$monkey/$scanID/functional

  # all Oxford data is the right way up (with with wrong orientation labels)
  cmdReorient="--reorient_func"
  flgFilter="hpbs" # band-stop filter needed in Oxford for the respirator
  # all Paris data is not the right way up (and sometimes with wrong orientation labels)
  if [[ $monkey == "guss" ]] ; then
    # all scans before 2017-01-11 have the wrong orientation labels
    # all scans after have the right orientation labels
    if [[ $(echo $scanID | cut -d'I' -f2) -lt 70111 ]] ; then
      cmdReorient="--swapdim_func"
    else
      cmdReorient="--reorient2std_func"
    fi
    flgFilter="hp" # no band-stop filter needed in Paris, they don't have the respirator
  fi

  # look for all available runs, or a specific set
  flgSingleRun=0
  if [[ -z $runSet ]] || [[ $runSet == "all" ]] ; then

    # look for multiple runs
    runList=$(find $funcDir -name "run[1-9]" -maxdepth 1 -type d)
    [[ -n $runList ]] && runList=$(find $funcDir/run[1-9] -name "raw_run[1-9].nii.gz" -maxdepth 1 -type f | sort)
    # if they don't exist, fall back to a single run
    [[ -z $runList ]] && runList=$(find $funcDir -name "raw.nii.gz" -maxdepth 1 -type f | sort) && flgSingleRun=1

  else

    # split a given list of runs on commas
    runSet=${runSet//,/ }
    nRunMerge=$(echo $runSet | wc -w)
    runList=""
    for run in $runSet ; do

      # test if a directory exists for this run
      if [[ -d $funcDir/run${run} ]] ; then
        run="$funcDir/run${run}/raw_run${run}.nii.gz"
      else
        run="$funcDir/raw_run${run}.nii.gz"
        if [[ ! -f $run ]] && [[ $nRunMerge -eq 1 ]] && [[ $runSet -lt 2 ]] ; then
          run="$funcDir/raw.nii.gz"
          flgSingleRun=1
        fi
      fi

      # add the requested run to the list (or give a warning)
      if [[ -f $run ]] ; then
        runList="$(printf "%s%s\n " "$runList" "$run")" # printf removes trailing newlines, so add a space to hack
      else
        >&2 printf "\nwarning: requested run has not been found\n%s\n\n" $run
      fi

    done

  fi

  # loop over the runs
  for funcRaw in $runList ; do
    funcDir=$(dirname $funcRaw)
    funcRaw=${funcRaw%%.*}

    # initialise or append the logfile
    logFile=$funcDir/procFunc.log
    [[ -s $logFile ]] && printf '\n\n\n\n' >> $logFile
    strLine=$(printf "_-%.0s" {1..28} | tr -d '_')
    printf "%s\nPROCESSING STARTED:\n$(date)\n%s\n\n" $strLine $strLine >> $logFile

    # extract the run number
    runIdx=$(echo ${funcRaw##*/} | grep -oh "raw_run[1-9]" | cut -d"n" -f2)
    [[ -z $runIdx ]] && runIdx=0

    # location and name of the processed data (and transforms)
    if [[ $flgSingleRun -eq 1 ]] ; then
      # store the transform in subj/transform
      subjDir=$(dirname $funcDir)
      funcProc=${funcDir}/func
    else
      printf "     run: %d\n" "$runIdx"
      # store the transforms in subj/functional/run/transform
      subjDir=$funcDir
      funcProc=${funcDir}/func_run${runIdx}
    fi

    # find the latest structural scan session
    structImg=$(find $structRootDir/$monkey/MI*/structural -name "struct.nii.gz" -type f -maxdepth 1 | sort | tail -1)

    # specify outlier instructions, if provided for this monkey/session/run
    if [[ -f $instructOutlierFile ]] ; then
      if [[ $flgSingleRun -eq 1 ]] ; then
        awk '($1=="'$scanID'")&&($2=="'$monkey'")&&($3=="'$site'"){print $0}' $instructOutlierFile | cut -d' ' -f4- > $funcDir/instructOutlier.txt
      else
        awk '($1=="'$scanID'")&&($2=="'$monkey'")&&($3=="'$site'")&&($4=="'$runIdx'"){print $0}' $instructOutlierFile | cut -d' ' -f5- > $funcDir/instructOutlier.txt
      fi
    fi

    # preprocess the rs-fMRI timeseries using the rsn_pipeline
    sh $MRCATDIR/pipelines/rfmri_macaque/rsn_pipeline.sh \
      --subjdir=$subjDir \
      --funcraw=$funcRaw \
      --funcproc=$funcProc \
      --structimg=$structImg \
      --logdir=$studyDir/log \
      --filter=hpbs \
      --masknoise="WMero_CSFero" \
      --ncompnoise=6 \
      --cleanpca 2>&1 | tee -a $logFile

      # whole list from start to finish
      #$cmdReorient --discardfirstvols --motioncorr --outlierdetect 2>&1 | tee -a $logFile
      # this might be a good place to check the outliers before continuing
      #--outliercut --register --biascorr --filter --cleancomp --lowpassvol --vol2surf --mask --smooth --mask --demean 2>&1 | tee -a $logFile

      # WM cleaning
      #--masknoise="WMcore" \
      #--cleancomp --lowpassvol --vol2surf --mask --smooth --mask --demean 2>&1 | tee -a $logFile

      # WM + CSF cleaning
      #--masknoise="WMcore_CSFcore" \
      #--cleancomp --lowpassvol --vol2surf --mask --smooth --mask --demean 2>&1 | tee -a $logFile

      # Paris WM + CSF cleaning
      #--masknoise="WMero_CSFcore" \
      #--cleancomp --lowpassvol --vol2surf --mask --smooth --mask --demean 2>&1 | tee -a $logFile

      # PCA dimensionality reduction
      #--cleanpca 2>&1 | tee -a $logFile

    echo ""
  done

done < $instructFile  # read instructions line by line


echo ""
echo "DONE"
echo "  seconds elapsed: $SECONDS"
echo ""
