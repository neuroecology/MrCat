#!/usr/bin/env bash

# clean up the error and output files created by fsl_sub by deleting the ones
# without errors. You can specify a folder to search in.

# Lennart Verhagen

# give help
if [[ $# -eq 0 ]] || [[ $# -gt 1 ]] ; then
  echo ""
  echo "clean up the error and output files of fsl_sub"
  echo ""
  echo "clean_logdir.sh <logdir>"
  echo ""
  exit 1
fi

# set logdir to the current directory if empty input
logdir="$1"
if [[ $logdir == "" ]] ; then
  logdir=./
fi

# find remove empty error and output files from the current and subdirectories
files2rm=$(find "$logdir" -name "*.e*" -type f -empty)
files2rm=$(echo "$files2rm" | sed 's/\.e/.*/g')
if test "$files2rm"; then
	rm $files2rm
fi

# find and remove temporary job scripts from the current and subdirectories
files2rm=$(find "$logdir" -name "tmp.*")
if test "$files2rm"; then
	rm $files2rm
fi

# find and remove core dump files from the current and subdirectories
files2rm=$(find "$logdir" -name "core.*")
if test "$files2rm"; then
	rm $files2rm
fi
