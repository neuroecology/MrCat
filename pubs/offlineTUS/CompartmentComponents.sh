#!/usr/bin/env bash
umask u+rw,g+rw # give group read/write permissions to all new files
set -e    # stop immediately on error

# retrieve input argument to find correct instructions
instructDir="$1"

# ------------------- #
# GENERAL DEFINITIONS
# ------------------- #
source $MRCATDIR/setupMrCat.sh
structRootDir="/Volumes/rsfMRI/structural/proc"
studyDir="/Volumes/rsfMRI/anaesthesia"
procDir="$studyDir/proc"
anaDir="$studyDir/analysis"

# retrieve the instruction file
instructFile=$procDir/$instructDir/instruct/instructProcFunc.txt
[[ ! -s $instructFile ]] && echo "" && >&2 printf "\nError: no valid instruction file found at:\n%s\n\n" $instructFile && exit 1
[[ $(tail -c1 $instructFile | wc -l) -le 0 ]] && echo "" >> $instructFile # ensure the instruction file ends with a newline character

# try to retrieve the dataset suffices, or opt for defaults
[[ -f $anaDir/instruct/sourceConfig.sh ]] && source $anaDir/instruct/sourceConfig.sh
[[ -z $surf ]] && surf="F99_10k"
[[ -z $suffixClean ]] && suffixClean="WMCSF" # "WMCSF", "WM"
suffix="_hpbs"
case $suffixClean in
  WMCSF ) maskNoise="WMcore_CSFcore" ;;
  WM ) maskNoise="WMcore" ;;
  CSF ) maskNoise="CSFcore" ;;
  GM ) maskNoise="GM" ;;
esac


# process instructions one line at a time
while read -r scanID monkey site runSet coord ; do
  printf "\n  monkey: %s\n" "$monkey"
  printf "    scan: %s (%s)\n" "$scanID" "$site"
  funcDir=$procDir/$site/$monkey/$scanID/functional
  structDir=$(find $structRootDir/$monkey/MI* -name "structural" -type d -maxdepth 1 | sort | tail -1)
  structBase="struct"
  structImg=$structDir/$structBase

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
    # extract the run number
    runIdx=$(echo ${funcRaw##*/} | grep -oh "raw_run[1-9]" | cut -d"n" -f2)
    [[ -z $runIdx ]] && runIdx=0
    [[ $flgSingleRun -ne 1 ]] && printf "     run: %d\n" "$runIdx"

    # unpack the file name
    funcDir=$(dirname $funcRaw)
    funcRaw=$(basename $funcRaw)
    funcExt=${funcRaw#*.}
    funcRaw=${funcRaw%%.*}
    [[ $funcExt != $funcRaw ]] && funcExt=".$funcExt" || funcExt=""
    funcRaw=$funcDir/$funcRaw
    transDir=$(cd $funcDir/transform; pwd)

    #-----------------------------------
    # please place your operations below
    #-----------------------------------
    # here be dragons

    # infer the name of the processed image
    if [[ $flgSingleRun -ne 1 ]] ; then
      funcBase="func_run${runIdx}"
      subjDir=$funcDir
    else
      funcBase="func"
      subjDir=$(dirname $funcDir)
    fi
    funcProc=$funcDir/${funcBase}
    funcImg=${funcProc}${suffix}

    # specify the images and confounds
    nComp=6
    confoundNoise=${funcImg}_${maskNoise}_comp.txt

    # warp mask from structural to function if it doesn't exist
    if [[ ! -f ${funcDir}/${maskNoise}.nii.gz ]] ; then
      applywarp --interp=nn -i $structDir/$maskNoise -r $funcDir/${funcBase}_brain_mask --premat=$transDir/${structBase}_to_${funcBase}.mat -o $funcDir/$maskNoise
    fi

    # principal component analysis
    $MATLABBIN/matlab -nodisplay -nosplash -r "addpath('$MRCATDIR');setupMrCat;rsn_decomp({'${funcImg}.nii.gz','${funcDir}/${maskNoise}.nii.gz'},$nComp,'pca','${funcImg}_${maskNoise}');exit"

    #-----------------------------------
    # please place your operations above
    #-----------------------------------

  done

done < $instructFile


echo ""
echo "DONE"
echo "  seconds elapsed: $SECONDS"
echo ""
