#!/usr/bin/env bash
umask u+rw,g+rw # give group read/write permissions to all new files
set -e    # stop immediately on error

# retrieve input argument to find correct instructions
instructDir="$1"

# ------------------- #
# GENERAL DEFINITIONS
# ------------------- #
source $MRCATDIR/setupMrCat.sh
origDir="/Volumes/rsfMRI/anaesthesia/orig"
studyDir="/Volumes/rsfMRI/anaesthesia/proc"
instructFile=$studyDir/$instructDir/instruct/instructInitFunc.txt
[[ ! -s $instructFile ]] && echo "" && >&2 printf "\nError: no valid instruction file found at:\n%s\n\n" $instructFile && exit 1

# ensure instructFile ends with a newline character
[[ $(tail -c1 $instructFile | wc -l) -le 0 ]] && echo "" >> $instructFile

# start a timer
SECONDS=0

# ------------------- #
# REPETITION TIME
# ------------------- #
# set your repetition time in seconds
TR=2.0075


# ------------ #
# COPYING DATA
# ------------ #
echo ""
echo "COPYING RS-FMRI DATA"

# print out the instructions
echo "instructions:"
cat $instructFile
echo ""

# loop over instructions
echo "working on:"
while read -r scanID monkey site runSet coord ; do
  printf "  monkey: %s\n" "$monkey"
  printf "    scan: %s (%s)\n" "$scanID" "$site"
  # if the set is "all", do not specify any
  [[ $runSet == "all" ]] && runSet=""

  # look for the most common file name structure
  # the files ending in *1[A-Z].nii.gz are copies, it seems. Ignore.
  runList=$(find ${origDir}/${scanID} -name "*ep2d*fmri*vols*1.nii.gz" -maxdepth 1 -type f | sort)
  # fall-back to a default
  [[ -z $runList ]] && runList=$(find ${origDir}/${scanID} -name "*ep2d*fmri*vols*.nii.gz" -maxdepth 1 -type f | sort)

  # try the Paris naming style
  flgParis=0
  if [[ -z $runList ]] ; then
    # find the datasets
    find ${origDir}/${scanID} -name "f*_S*_RS_fMRI*.nii.gz" -maxdepth 1 -type f > ${origDir}/${scanID}/fileList.txt
    [[ -s ${origDir}/${scanID}/fileList.txt ]] && flgParis=1
    # sort them according to the scan number
    runList=$(cat ${origDir}/${scanID}/fileList.txt | rev | cut -d'/' -f1 | rev | cut -d'_' -f2 | paste - ${origDir}/${scanID}/fileList.txt | sort -k 1 | awk '{print $2}')
    rm -f ${origDir}/${scanID}/fileList.txt
  fi

  # give a warning when empty
  [[ -z $runList ]] && echo "      no runs found!"

  # check the runs for length
  runListAccepted=""
  for origData in $runList ; do
    # check whether at least 80% of the expected number of volumes are present,
    # otherwise, assume this run was aborted
    nVolExpected=$(echo $origData | grep -oh "[0-9]*vols" | cut -d"v" -f1)
    [[ $flgParis -eq 1 ]] && nVolExpected=$(basename $origData | cut -d'_' -f1 | tr -d 'f')
    nVolFound=$(fslval $origData dim4)
    nVolTooFew=$(echo $nVolFound $nVolExpected | awk '($1 < $2*0.8){print "TRUE"}')
    [[ $nVolTooFew == "TRUE" ]] && continue

    # check whether the run lasted at least 5 minutes
    TR=$(fslval $origData pixdim4)
    nVolTooFew=$(echo $nVolFound $TR | awk '($1 < 300/$2){print "TRUE"}')
    [[ $nVolTooFew == "TRUE" ]] && continue

    # the run is accepted, add it to the list
    runListAccepted+=" $origData"
  done

  # give a warning when no good runs have been identified
  nRun=$(echo "$runListAccepted" | wc -w)
  [[ -n $runList ]] && [[ $nRun -lt 1 ]] && echo "      no good runs found!"

  # loop over the runs
  c=0;
  for origData in $runListAccepted ; do
    ((++c))

    # skip this run when a selected set is specified, but the current run is not part of it
    [[ -n $runSet ]] && [[ ! $runSet =~ $c ]] && continue

    # specify the desired location and name for the rs-fMRI data
    if [[ $nRun -gt 1 ]] ; then
      printf "     run: %d\n" "$c"
      funcDir=$studyDir/$site/$monkey/$scanID/functional/run$c
      funcRaw=$funcDir/raw_run$c
    else
      funcDir=$studyDir/$site/$monkey/$scanID/functional
      funcRaw=$funcDir/raw
    fi

    # copy the original data to the working directory
    mkdir -p $funcDir
    # the Paris data is converted to floating point notation, the Oxford data has a forced TR
    if [[ $flgParis -eq 1 ]] ; then
      #imcp $origData $funcRaw
      fslmaths -dt float $origData $funcRaw -odt float
    else
      fslmaths -dt float $origData $funcRaw -odt float
      fslmerge -tr $funcRaw $funcRaw $TR
    fi

  done

done < $instructFile  # read instructions line by line


echo ""
echo "DONE"
echo "  seconds elapsed: $SECONDS"
echo ""
