#!/usr/bin/env bash
umask u+rw,g+rw # give group read/write permissions to all new files
set -e    # stop immediately on error

# TODO: when not all runs are included, be clever in the $c counter and the run specific merge

# retrieve input argument to find correct instructions
instructDir="$1"

# ------------------- #
# GENERAL DEFINITIONS
# ------------------- #
source $MRCATDIR/setupMrCat.sh
mergeMethodGroup="MIGP" # simple concatenation (CONCAT) or group-PCA (MIGP)
mergeMethodGroupRun="MIGP" # simple concatenation (CONCAT) or group-PCA (MIGP)
studyDir="/Volumes/rsfMRI/anaesthesia"
procDir="$studyDir/proc"
anaDir="$studyDir/analysis"
dataMask=$MRCATDIR/data/macaque/F99/surf/cortex_subcort.roi.F99_10k.dscalar.nii

# try to retrieve the dataset suffices, or opt for defaults
[[ -f $anaDir/instruct/sourceConfig.sh ]] && source $anaDir/instruct/sourceConfig.sh
[[ -z $suffixClean ]] && suffixClean="WMCSF"
[[ -z $suffixTS ]] && suffixTS="_hpbs_clean${suffixClean}_lp.smooth"
[[ -z $surf ]] && surf="F99_10k"
[[ -z $flgValidate ]] && flgValidate=0 && suffixValidate=""

# retrieve the instruction file
instructFile=$procDir/$instructDir/instruct/instructMergeFunc.txt
[[ ! -s $instructFile ]] && echo "" && >&2 printf "\nError: no valid instruction file found at:\n%s\n\n" $instructFile && exit 1
[[ $(tail -c1 $instructFile | wc -l) -le 0 ]] && echo "" >> $instructFile # ensure the instruction file ends with a newline character


# start a timer
SECONDS=0


# ------------------------ #
# MERGING DENSE TIMESERIES
# ------------------------ #
echo ""
echo "MERGING DENSE TIMESERIES"
echo "time-series input suffix:   $suffixTS"
echo ""

# print out the instructions
echo "instructions:"
cat $instructFile
echo ""

# definitions
nMonkey=$(wc -l < $instructFile)
site=$(awk '{print $3}' < $instructFile | sort | uniq)
[[ $(echo "$site" | wc -l) -eq 1 ]] && workDir=$procDir/$site || workDir=$procDir
mergeFile=$procDir/$instructDir/instruct/cmdMerge.txt
> $mergeFile


# ------------ #
# SPECIFY DATA
# ------------ #

# loop over instructions
echo "working on:"
while read -r scanID monkey site runSet coord ; do
  printf "  monkey: %s\n" "$monkey"
  printf "    scan: %s (%s)\n" "$scanID" "$site"
  funcDir=$procDir/$site/$monkey/$scanID/functional

  # look for all available runs, or a specific set
  if [[ -z $runSet ]] || [[ $runSet == "all" ]] ; then

    # look for multiple runs
    runList=$(find $funcDir -name "run[1-9]" -maxdepth 1 -type d)
    [[ -n $runList ]] && runList=$(find $funcDir/run[1-9] -name "func_run[1-9]${suffixTS}.${surf}.dtseries.nii" -maxdepth 1 -type f | sort)
    # if they don't exist, fall back to a single run
    [[ -z $runList ]] && runList=$(find $funcDir -name "func${suffixTS}.${surf}.dtseries.nii" -maxdepth 1 -type f | sort)

  else

    # split a given list of runs on commas
    runSet=${runSet//,/ }
    nRunMerge=$(echo $runSet | wc -w)
    runList=""
    for run in $runSet ; do

      # test if a directory exists for this run
      if [[ -d $funcDir/run${run} ]] ; then
        run="$funcDir/run${run}/func_run${run}${suffixTS}.${surf}.dtseries.nii"
      else
        run="$funcDir/func_run${run}${suffixTS}.${surf}.dtseries.nii"
        if [[ ! -f $run ]] && [[ $nRunMerge -eq 1 ]] && [[ $runSet -lt 2 ]] ; then
          run="$funcDir/func${suffixTS}.${surf}.dtseries.nii"
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

  # add the runs to an array (using the right index)
  runArray=()
  maxRunIdx=0
  printf "     run:"
  for funcProc in $runList ; do
    # extract the run number
    runIdx=$(echo ${funcProc##*/} | grep -oh "func_run[1-9]" | cut -d"n" -f3)
    [[ -z $runIdx ]] && runIdx=1
    printf " %d" $runIdx
    # store the highest run number
    [[ $runIdx -gt $maxRunIdx ]] && maxRunIdx=$runIdx
    # assign run to the array at the right index
    runArray[$runIdx]=$funcProc
  done
  echo ""

  # replace missing runs by "MISSING"
  for runIdx in $(seq 1 $maxRunIdx) ; do
    runArray[$runIdx]=$(echo "${runArray[$runIdx]:-MISSING}")
  done

  # store the runs in a text file
  echo "${runArray[@]}" >> $mergeFile

done < $instructFile  # read instructions line by line


# -------------- #
# MERGE DATASETS
# -------------- #

# merge runs per session
echo "  concatenating runs per session/monkey"
cmdMigpGroup="{"
while read -r runList ; do

  # extract the directory of the functional data (ignoring missing runs)
  funcDir=$(echo "$runList" | sed "s# *MISSING *##g" | sed "s#$procDir##g" | cut -d"/" -f1,2,3,4,5)
  funcDir=${procDir}${funcDir}

  # construct a list of runs to merge (ignore the missing runs)
  cmdMerge=$(echo $runList | tr " " "\n" | awk '($1 != "MISSING"){print "-cifti " $1}' | tr "\n" " ")
  outputFile=$funcDir/func${suffixTS}.${surf}.dtseries.nii

  # merge the selected runs (if more than one), or copy (if only one run from a larger set is selected)
  if [[ $(echo $cmdMerge | wc -w) -gt 2 ]] ; then
    wb_command -cifti-merge $outputFile $cmdMerge
  elif [[ $(echo $cmdMerge | wc -w) -eq 2 ]] ; then
    inputFile=$(echo $cmdMerge | awk '{print $2}')
    [[ $inputFile != $outputFile ]] && cp $inputFile $outputFile
  fi

  # add each monkey with at least one run to the group-merge command
  if [[ -n $cmdMerge ]] ; then
    [[ $cmdMigpGroup != "{" ]] && cmdMigpGroup+=","
    cmdMigpGroup+="'$outputFile'"
  fi

done < $mergeFile
cmdMigpGroup+="}"


# merge sessions per monkey
flgReport=1

# check how many times the same subject is listed for this site
subjList=$(awk '{print $2}' $instructFile)
subjUniqueList=$(echo "$subjList" | sort | uniq)

for subjName in $subjUniqueList ; do
  instructSubj=$procDir/$instructDir/instruct/tmp.instructMergeSessPerSubj.txt
  awk '($2 == "'$subjName'"){print $0}' $instructFile > $instructSubj

  # merge sessions for subjects who have more than one session
  if [[ $(wc -l $instructSubj | awk '{print $1}') -gt 1 ]] ; then

    # collect sessions to merge
    cmdMerge=""
    while read -r scanID monkey site runSet coord ; do

      # specify the session dataset
      funcData=$procDir/$site/$monkey/$scanID/functional/func${suffixTS}.${surf}.dtseries.nii

      # if the subject dataset exists, add it to the merge command
      [[ -f $funcData ]] && cmdMerge+=" $funcData"

    done < $instructSubj

    # merge sessions, if they are present
    if [[ -n $cmdMerge ]] ; then

      # report
      if [[ $flgReport -eq 1 ]] ; then
        echo "  concatenating sessions per monkey"
        flgReport=0
      fi

      cmdMerge=$(echo $cmdMerge | tr " " "\n" | awk '{print "-cifti " $1}' | tr "\n" " ")
      outputFile=$workDir/$subjName/func${suffixTS}.${surf}.dtseries.nii
      wb_command -cifti-merge $outputFile $cmdMerge

    fi

  fi

  rm -rf $instructSubj

done


# merge sessions per run
[[ $mergeMethodGroup != "MIGP" ]] && echo "  concatenating sessions/monkeys per run"

# find the maximum number of runs over all monkeys
maxRunIdx=$(awk '{print NF}' $mergeFile | sort -nr | head -1)

cmdMigpGroupRun=""
if [[ $maxRunIdx -gt 1 ]] ; then

  # loop over runs
  for c in $(seq 1 $maxRunIdx) ; do

    # set the output file
    outputFile=$workDir/func_run${c}${suffixTS}${suffixValidate}.${surf}.dtseries.nii

    # prepare merger using concatenation or MIGP
    if [[ $mergeMethodGroupRun == "MIGP" ]] ; then

      cmdMerge=$(awk -v q="'" '($"'$c'" != "MISSING" && $"'$c'" != ""){print q $"'$c'" q}' $mergeFile | tr "\n" " ")
      cmdMerge=$(echo $cmdMerge | tr " " ",")
      cmdMerge="{$cmdMerge}"
      cmdMigpGroupRun+="MIGP($cmdMerge,'$outputFile',250,200,0,'${WBBIN}/wb_command');"

    else

      # construct a list of runs to merge (ignore the missing runs)
      cmdMerge=$(awk '($"'$c'" != "MISSING" && $"'$c'" != ""){print "-cifti " $"'$c'"}' $mergeFile | tr "\n" " ")
      # merge the selected runs, if available
      if [[ -n $cmdMerge ]] ; then
        wb_command -cifti-merge $outputFile $cmdMerge
      fi

    fi

  done

fi


# group analysis

# prepare merger using concatenation or MIGP
outputFile=$workDir/func${suffixTS}${suffixValidate}.${surf}.dtseries.nii

if [[ $mergeMethodGroup == "MIGP" ]] ; then

  # combine monkeys using MIGP
  cmdMigpGroup="MIGP($cmdMigpGroup,'$outputFile',250,200,0,'${WBBIN}/wb_command')"

else

  echo "  concatenating all to create a group dataset"
  # construct a list of runs to merge (ignore the missing runs)
  cmdMerge=$(cat $mergeFile | tr " " "\n" | awk '($1 != "MISSING"){print "-cifti " $1}' | tr "\n" " ")
  wb_command -cifti-merge $outputFile $cmdMerge

fi


# exectute all matlab MIGP commands in one go
cmdMIGP=""
[[ $mergeMethodGroupRun == "MIGP" ]] && cmdMIGP+="$cmdMigpGroupRun"
[[ $mergeMethodGroup == "MIGP" ]] && cmdMIGP+="$cmdMigpGroup"
if [[ -n $cmdMIGP ]] ; then
  echo "  agregating datasets using MIGP"
  $MATLABBIN/matlab -nodisplay -nosplash -r "addpath('$MRCATDIR');setupMrCat;$cmdMIGP;exit"
fi


# clean up
rm -rf $mergeFile

echo ""
echo "DONE"
echo "  seconds elapsed: $SECONDS"
echo ""
