#!/usr/bin/env bash

# ensure a valid job identifier
jobID="$*"                              # concatenate all input into a variable
jobID=$(echo "$jobID" | tr [:space:] ,) # replace spaces with commas
jobID=$(echo "$jobID" | tr -s ,)        # squeeze series of commas to single
jobID=${jobID#,}; jobID=${jobID%,}      # trim leading and trailing commas
[[ -z $jobID ]] && jobID="donthold"     # use a placeholder if empty
echo $jobID                             # echo to standard output
