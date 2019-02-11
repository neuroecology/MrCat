#!/usr/bin/env bash
umask u+rw,g+rw # give group read/write permissions to all new files
set -e    # stop immediately on error

# ---------- #
# USAGE
# ---------- #
usage() {
cat <<EOF

Setup the instructions for FUN rs-fMRI preprocessing. Sites to choose from:
sma, psma, pgacc, fpc, lofc, amyg, midsts, control, ppsma, pcontrol, pv1, punknown

example:
  sh SetupInstruct.sh sma

usage:
  SetupInstruct.sh <site>

EOF
}


# ---------- #
# OVERHEAD
# ---------- #
# if no arguments are given, or help is requested, return the usage
[[ $# -eq 0 ]] || [[ $@ =~ --help ]] && usage && exit 0

# if too many arguments given, return the usage, exit with error
[[ $# -gt 1 ]] && echo "" && >&2 printf "\nError: too many input arguments.\n\n" && usage && exit 1

# retrieve input argument
site="$1"


# ------------------- #
# GENERAL DEFINITIONS
# ------------------- #
source $MRCATDIR/setupMrCat.sh
studyDir="/Volumes/rsfMRI/anaesthesia/proc"
structDir="/Volumes/rsfMRI/structural/proc"
instructFile=$studyDir/instruct/instructGood.txt
[[ ! -s $instructFile ]] && echo "" && >&2 printf "\nError: no valid instruction file found at:\n%s\n\n" $instructFile && exit 1
instructions="$(awk '($3 == "'$site'"){print $0}' $instructFile)"

# test if the requested site exists
[[ -z $instructions ]] && echo "" && >&2 printf "\nError: requested site (\"%s\") not supported.\n" $site && usage && exit 1


# --------------- #
# HERE BE DRAGONS
# --------------- #
# ensure a directory for the requested site exists
mkdir -p $studyDir/$site/instruct
mkdir -p $structDir/instruct

# extract the sessions belonging to this site
echo "$instructions" > $studyDir/$site/instruct/instructInitFunc.txt

# copy to all other instructions
cp $studyDir/$site/instruct/instructInitFunc.txt $structDir/instruct/instructProcStruct.txt
cp $studyDir/$site/instruct/instructInitFunc.txt $studyDir/$site/instruct/instructProcFunc.txt
cp $studyDir/$site/instruct/instructInitFunc.txt $studyDir/$site/instruct/instructMergeFunc.txt

# copy to the processing directory as the default instructions
cp $studyDir/$site/instruct/instructInitFunc.txt $studyDir/instruct/instructInitFunc.txt
cp $studyDir/$site/instruct/instructProcFunc.txt $studyDir/instruct/instructProcFunc.txt
cp $studyDir/$site/instruct/instructMergeFunc.txt $studyDir/instruct/instructMergeFunc.txt
