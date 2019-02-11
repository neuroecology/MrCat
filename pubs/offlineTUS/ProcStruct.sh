#!/usr/bin/env bash
umask u+rw,g+rw # give group read/write permissions to all new files
set -e    # stop immediately on error


# ------------------- #
# GENERAL DEFINITIONS
# ------------------- #
source $MRCATDIR/setupMrCat.sh
studyDir="/Volumes/rsfMRI/structural/proc"
instructFile=$studyDir/instruct/instructProcStruct.txt
[[ ! -s $instructFile ]] && echo "" && >&2 printf "\nError: no valid instruction file found at:\n%s\n\n" $instructFile && exit 1

# ensure instructFile ends with a newline character
[[ $(tail -c1 $instructFile | wc -l) -le 0 ]] && echo "" >> $instructFile

# start a timer
SECONDS=0


# ------------------ #
# PROCESS STRUCTURAL
# ------------------ #
echo ""
echo "PROCESS STRUCTURAL"

# extract the monkeys to run (remove duplicates)
monkeyList=$(awk '{print $2}' $instructFile | sort | uniq)

# loop over monkeys
for monkey in $monkeyList ; do
  echo "  $monkey"

  # count the number of sessions
  nSess=$(echo $studyDir/$monkey/* | awk '{print NF}')
  [[ $nSess -gt 1 ]] && echo "    $nSess sessions found"

  # loop over sessions
  ss=0
  for monkeyDir in $studyDir/$monkey/MI* ; do
    [[ $nSess -gt 1 ]] && echo "processing session $((++ss)) of $nSess"

    # run preproc_struct through the rsn_pipeline for consistency
    sh $MRCATDIR/pipelines/rfmri_macaque/rsn_pipeline.sh \
      --subjdir=$monkeyDir \
      --structimg=$monkeyDir/structural/struct \
      --preproc_struct

  done

done

echo ""
echo "DONE"
echo "  seconds elapsed: $SECONDS"
echo ""
