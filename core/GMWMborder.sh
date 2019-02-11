#!/usr/bin/env bash

# create binary masks of grey, white and combined borders

# Lennart Verhagen

# give help
if [[ $# -lt 1 ]] || [[ $# -gt 5 ]] ; then
  echo ""
  echo "create binary masks of grey, white and combined borders"
  echo ""
  echo "GMWMborder.sh <GM> <WM> [kernelSize] [outputBase] [outputAppend]"
  echo ""
  exit 1
fi

# find the working directory
p_seg="${1%/*}"
if [[ $p_seg == $1 ]] ; then p_seg="." ; fi

#set kernel_size and pre
if [[ $3 == *[0-9]* ]] ; then
  kernel="$3"
  pre="$4"
  post="$5"
else
  kernel=2
  pre="$3"
  post="$4"
fi
if [[ $pre == "" ]] ; then
  pre=$p_seg/
fi
if [[ ${pre: -1} != / ]] && [[ ${pre: -1} != _ ]] ; then
  pre=${pre}_
fi

# dilate the segments and mask
fslmaths $2 -kernel sphere $kernel -dilD -mas $1 ${pre}GMborder${post}
fslmaths $1 -kernel sphere $kernel -dilD -mas $2 ${pre}WMborder${post}
fslmaths ${pre}GMborder${post} -add ${pre}WMborder${post} ${pre}GMWMborder${post}
