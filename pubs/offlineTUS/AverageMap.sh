#!/usr/bin/env bash
umask u+rw,g+rw # give group read/write permissions to all new files
set -e    # stop immediately on error

# retrieve input argument to find correct instructions
instructDir="$1"

# ------------------- #
# GENERAL DEFINITIONS
# ------------------- #
source $MRCATDIR/setupMrCat.sh
studyDir="/Volumes/rsfMRI/anaesthesia"
procDir="$studyDir/proc"
anaDir="$studyDir/analysis"
dataMask=$MRCATDIR/data/macaque/F99/surf/cortex_subcort.roi.F99_10k.dscalar.nii

# try to retrieve the dataset suffices, or opt for defaults
[[ -f $anaDir/instruct/sourceConfig.sh ]] && source $anaDir/instruct/sourceConfig.sh
[[ -z $suffixClean ]] && suffixClean="WMCSF"
[[ -z $surf ]] && surf="F99_10k"
#suffix="_hpbs_clean${suffixClean}beta.smooth"
suffix="_hpbs_clean${suffixClean}tstat.smooth"
#suffix="_hpbs_confound${suffixClean}.smooth.stdev"

# retrieve the instruction file
instructFile=$procDir/$instructDir/instruct/instructMergeFunc.txt
[[ ! -s $instructFile ]] && echo "" && >&2 printf "\nError: no valid instruction file found at:\n%s\n\n" $instructFile && exit 1
[[ $(tail -c1 $instructFile | wc -l) -le 0 ]] && echo "" >> $instructFile # ensure the instruction file ends with a newline character


# start a timer
SECONDS=0


# ----------------------------- #
# AVERAGING DENSE SCALAR IMAGES
# ----------------------------- #
echo ""
echo "AVERAGING DENSE SCALAR IMAGES"

# print out the instructions
echo "instructions:"
cat $instructFile
echo ""

# definitions
nMonkey=$(wc -l < $instructFile)
site=$(awk '{print $3}' < $instructFile | sort | uniq)
[[ $(echo "$site" | wc -l) -eq 1 ]] && workDir=$procDir/$site || workDir=$procDir
avgFile=$procDir/$instructDir/instruct/cmdAvg.txt
> $avgFile

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
    [[ -n $runList ]] && runList=$(find $funcDir/run[1-9] -name "func_run[1-9]${suffix}.${surf}.dscalar.nii" -maxdepth 1 -type f | sort)
    # if they don't exist, fall back to a single run
    [[ -z $runList ]] && runList=$(find $funcDir -name "func${suffix}.${surf}.dscalar.nii" -maxdepth 1 -type f | sort)

  else

    # split a given list of runs on commas
    runSet=${runSet//,/ }
    nRunMerge=$(echo $runSet | wc -w)
    runList=""
    for run in $runSet ; do

      # test if a directory exists for this run
      if [[ -d $funcDir/run${run} ]] ; then
        run="$funcDir/run${run}/func_run${run}${suffix}.${surf}.dscalar.nii"
      else
        run="$funcDir/func_run${run}${suffix}.${surf}.dscalar.nii"
        if [[ ! -f $run ]] && [[ $nRunMerge -eq 1 ]] && [[ $runSet -lt 2 ]] ; then
          run="$funcDir/func${suffix}.${surf}.dscalar.nii"
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
  for runFileName in $runList ; do
    # extract the run number
    runIdx=$(echo ${runFileName##*/} | grep -oh "func_run[1-9]" | cut -d"n" -f3)
    [[ -z $runIdx ]] && runIdx=1
    printf " %d" $runIdx
    # store the highest run number
    [[ $runIdx -gt $maxRunIdx ]] && maxRunIdx=$runIdx
    # assign run to the array at the right index
    runArray[$runIdx]=$runFileName
  done
  echo ""

  # replace missing runs by "MISSING"
  for runIdx in $(seq 1 $maxRunIdx) ; do
    runArray[$runIdx]=$(echo "${runArray[$runIdx]:-MISSING}")
  done

  # store the runs in a text file
  echo "${runArray[@]}" >> $avgFile

done < $instructFile  # read instructions line by line


# merge the datasets
echo "  averaging runs per monkey"
cmdAvgGroup=""
while read -r runList ; do
  # extract the directory of the functional data (ignoring missing runs)
  funcDir=$(echo "$runList" | sed "s# *MISSING *##g" | sed "s#$procDir##g" | cut -d"/" -f1,2,3,4,5)
  funcDir=${procDir}${funcDir}
  # construct a list of runs to merge (ignore the missing runs)
  cmdAvg=$(echo $runList | tr " " "\n" | awk '($1 != "MISSING"){print "-cifti " $1}' | tr "\n" " ")
  # merge the selected runs (if more than one)
  if [[ $(echo $cmdAvg | wc -w) -gt 2 ]] ; then
    wb_command -cifti-average $funcDir/func${suffix}.${surf}.dscalar.nii $cmdAvg
  fi
  # construct command to create a group average
  cmdAvgGroup+=" -cifti $funcDir/func${suffix}.${surf}.dscalar.nii"
done < $avgFile


echo "  averaging monkeys per run"
# find the maximum number of runs over all monkeys
maxRunIdx=$(awk '{print NF}' $avgFile | sort -nr | head -1)
if [[ $maxRunIdx -gt 1 ]] ; then
  for c in $(seq 1 $maxRunIdx) ; do
    # construct a list of runs to merge (ignore the missing runs)
    cmdAvg=$(awk '($"'$c'" != "MISSING" && $"'$c'" != ""){print "-cifti " $"'$c'"}' $avgFile | tr "\n" " ")
    # merge the selected runs, if available
    if [[ -n $cmdAvg ]] ; then
      wb_command -cifti-average $workDir/func_run${c}${suffix}.${surf}.dscalar.nii $cmdAvg
    fi
  done
fi


echo "  averaging monkeys to create a group average"
wb_command -cifti-average $workDir/func${suffix}.${surf}.dscalar.nii $cmdAvgGroup


# clean up
rm -rf $avgFile

echo ""
echo "DONE"
echo "  seconds elapsed: $SECONDS"
echo ""
