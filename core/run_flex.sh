#!/usr/bin/env bash
set -e    # stop immediately on error
umask u+rw,g+rw # give group read/write permissions to all new files

# This is template script for a flexible instruction-based processing pipeline

# This script can be run over fsl_sub, for example using something like:
#   fsl_sub -N runscript -q veryshort.q -l $logDir run.sh
# where "$logDir" refers to a logfile directory, for example:
#   scratch=/vols/Scratch/lverhagen
#   limbic=$scratch/limbic/human
#   logDir=$scratch/limbic/scripts/log
#   mkdir -p $logDir
# then you could clean up afterwards using something like:
#   sh $MRCATDIR/core/clean_logdir.sh $logDir
# or automated on the que as:
#   fsl_sub -N cleanup -j runscript -q veryshort.q -l $logDir sh $MRCATDIR/core/clean_logdir.sh $logDir
# if you want to submit multiple lines to the queue you're probably best off
# to write commands to a temporary file. Initialise this file using:
#   tmpFile=$(mktemp "$logDir/tmp.$(basename $0).imcp.XXXXXXXXXX")
#   chmod +x $tmpFile
# and then write commands like:
#   echo -n my_first_command"; " >> $tmpFile
#   echo -n my_second_command"; " >> $tmpFile
# and submit (execute) the temp file:
#   jobID=$(fsl_sub -N myjob -q veryshort.q -l $logDir $tmpFile)
# and maybe ensure an acceptable job ID to let the next stage wait on:
#   jobID=$(sh $MRCATDIR/core/jobID.sh $jobID)


# ------------------------------ #
# usage
# ------------------------------ #

usage() {
cat <<EOF

This is template script for a flexible instruction-based processing pipeline. It
will run the specified instructions in the given order.

example:
      $(basename $0) --workdir=$(pwd) --subjlist=subj1 --basename=struct --A --B

usage: $(basename $0)
      [--all] : execute all instructions A, B, B, A, C, A, C
      [--ABBA] : execute instructions A, B, B, A
      [--A] : execute instruction A
      [--B] : execute instruction B
      [--C] : execute instruction C
      [--workdir=<working directory>] (default: <current directory>)
      [--subjlist=<list of subjects>] (default: subj1@subj2@etc)
      [--basename=<base of input/output filename>] (default: struct)

EOF
}


# ------------------------------ #
# overhead
# ------------------------------ #

# if no arguments given, or help is requested, return the usage
if [[ $# -eq 0 ]] || [[ $@ =~ --help ]] ; then usage; exit 0; fi

# if too few arguments given, return the usage, exit with error
if [[ $# -lt 1 ]] ; then >&2 usage; exit 1; fi

# if directory of this scirpt is not given, retrieve it
[[ $0 == */* ]] && thisScript=$0 || thisScript="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/$0
scriptDir=$(dirname $thisScript)

# if no input or "--all" is given, run the default set
defaultSet="--A --B --B --A --C --A --C"
if [[ $# -eq 0 ]] || [[ "$@" =~ --all ]] ; then
  echo "running the complete set of instructions: $defaultSet"
  # execute this script with the default argument set, and passing others
  [[ $# -eq 0 ]] && newArg=$defaultSet || newArg=$(echo "${@//--all/$defaultSet}")
  sh $thisScript $newArg
  exit 0
elif [[ "$@" =~ --ABBA ]] ; then
  selectedSet="--A --B --B --A"
  echo "running the instructions: $selectedSet"
  # execute this script with the selected argument set, and passing others
  newArg=$(echo "${@//--ABBA/$selectedSet}")
  sh $thisScript $newArg
  exit 0
fi

# run each instruction on its own (with the same definitions)
definitionargs=$(echo "$@" | tr " " "\n" | grep '=') || true
instructargs=$(echo "$@" | tr " " "\n" | grep -v '=') || true
if [[ $(echo "$instructargs" | wc -w) -gt 1 ]] ; then
  # this ensures the instructions are executed as specified, not as coded below
  for instr in $instructargs ; do
    sh $thisScript $definitionargs $instr
  done
  exit 0
fi

# count and grep the number of argument repetitions (ignoring after "=")
duplicates=$(echo "$@" | tr " " "\n" | awk '{ gsub("=.*","="); print $0}' | sort | uniq -c | grep -v '^ *1 ') || true   # "|| true" is added to ignore the non-zero exit code of grep (and avoid the script the stop because of "set -e")
# now test if any duplicates were found, and if so, give an error
[[ -n $duplicates ]] && echo "\nError, repetitions found in the arguments:\n$@\n${duplicates}\n" && exit 1


# ------------------------------ #
# definitions and settings
# ------------------------------ #

# set defaults
instr=""
arg=""
studyDir="$(pwd)"
logDir="./log"
subjList="subj1 subj2 subj3 etc"
baseName="struct"

# parse the input arguments
for a in "$@" ; do
  case $a in
    -s=*|--subj=*|--subjlist=*)   subjList="${a#*=}"; shift ;;
    -b=*|--base=*|--basename=*)   baseName="${a#*=}"; shift ;;
    -d=*|--studydir=*)            studyDir="${a#*=}"; shift ;;
    -l=*|--logdir=*)              logDir="${a#*=}"; shift ;;
    --*)                          instr="$instr $a"; shift ;; # instruction argument
    *)                            arg="$arg $a"; shift ;; # unsupported argument
  esac
done

# check if no redundant arguments have been set
if [[ -n $arg ]] ; then
  >&2 echo ""; >&2 echo "unsupported arguments are given:" $arg
  usage; exit 1
fi

# replace "@" by spaces to create loop-able lists
subjList="${subjList//@/ }"

# HCP-pipelines and MrCat directories
if [[ $OSTYPE == darwin* ]] ; then # when running on OS X
  export HCPPIPEDIR=$HOME/code/HCP-pipelines
  tmpMRCATDIR=$HOME/code/MrCat-dev
elif [[ $OSTYPE == linux-gnu ]] ; then # when running on Linux
  export HCPPIPEDIR=/vols/Data/daa/scripts/HCP-pipelines
  tmpMRCATDIR=$HOME/scratch/MrCat-dev
fi
[[ -z $MRCATDIR ]] && export MRCATDIR=$tmpMRCATDIR

# ensure the study folder exists
mkdir -p $studyDir
studyDir=$(cd $studyDir && pwd)

# normally you would also ensure that the log folder exists, but this is just an example script
#mkdir -p $logDir
#logDir=$(cd $logDir && pwd)


# ------------------------------ #
# the instructions are coded below
# ------------------------------ #

# instruction A
if [[ $instr =~ --A$ ]] ; then
  echo "instruction A"

  # loop over subjects
  for s in $subjList ; do
    echo "  subject: $s"

  done
  echo "  done"
fi


# instruction B
if [[ $instr =~ --B$ ]] ; then
  echo "instruction A"

  # loop over subjects
  for s in $subjList ; do
    echo "  subject: $s"

  done
  echo "  done"
fi


# instruction C
if [[ $instr =~ --C$ ]] ; then
  echo "instruction A"

  # loop over subjects
  for s in $subjList ; do
    echo "  subject: $s"

  done
  echo "  done"
fi
