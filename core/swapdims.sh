#!/usr/bin/env bash
set -e    # stop immediately on error
umask u+rw,g+rw # give group read/write permissions to all new files

#--------------------------------------------------------------------------
# General dimension swapping for imaging files and vectors. This version created
# after discussion with Paul McCarthy about problems of FSL functions either
# automatically changing the sform or taking sform as the priorty over the
# qform. The solution is to explicitly amend the qform and copy that to the
# sform
#
# swapping of bvecs based on Karla Miller's swapbvecs
#
# version history
# 2018-10-02	Rogier   created original
#
# copyright
# Rogier B. Mars
# University of Oxford & Donders Institute, 2016-2018
#--------------------------------------------------------------------------

# ------------------------------ #
# usage
# ------------------------------ #
usage() {
cat <<EOF

  sh swapdims <infile> <x> <y> <z> <outfile> <filetype>
  infile 		   : full file name of input
  x, y, z		   : axes in convention of fslswapdim
  outfile		   : full file name of ouput
  filetype     : work on "image" or "bvecs"

EOF
}

# ============================================
# housekeeping
# ============================================

infile=$1
x=$2
y=$3
z=$4
outfile=$5
filetype=$6

# ============================================
# Do the work
# ============================================

case "$filetype" in

  image)

    # echo "working on an image"

    fslswapdim $infile $x $y $z $outfile
    pixdim1=`fslval $infile pixdim1`
    pixdim2=`fslval $infile pixdim2`
    pixdim3=`fslval $infile pixdim3`
    fslorient -setsform -$pixdim1 0 0 0 0 $pixdim2 0 0 0 0 $pixdim3 0 0 0 0 1 $outfile
    fslorient -setsformcode 1 $outfile
    fslorient -copysform2qform $outfile

    ;;

  bvecs)

    # echo "working on bvecs"

    $MRCATDIR/core/swapbvecs $infile $x $y $z $outfile

    ;;

esac
