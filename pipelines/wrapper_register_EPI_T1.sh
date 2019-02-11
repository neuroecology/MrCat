#!/usr/bin/env bash
set -e    # stop immediately on error
umask u+rw,g+rw # give group read/write permissions to all new files

# a wrapper to register diffusion and structural images
#--------------------------------------------------------------------------
# version history
# 2016-03-01	Lennart		created
#
# copyright
# Lennart Verhagen & Rogier B. Mars
# University of Oxford & Donders Institute, 2016-03-01
#--------------------------------------------------------------------------


#==========================================
# Edit this part
#==========================================

# data root directory
rootdir=/vols/Data/rbmars/social_macaquediffusion

# if MRCATDIR is not defined in the environment
[[ -z $MRCATDIR ]] && export MRCATDIR=$(cd ..; pwd)


#==========================================
# Sort the input options (probably don't need to edit this part)
#==========================================

usage() {
cat <<EOF

Register the diffusion and structural spaces to each other, using the nodif and
T1-weighted structural images.

usage: wrapper_register_dMRI_struct.sh <subjname> <flgBET>
  <subjname> : a single subject name, or a list of comma-separated names, as in:
    KingKong,Cheeta,Rafiki

EOF
}

# give usage if no input is provided
[[ $# -eq 0 ]] && usage && exit 0

# retrieve the subject name(s) from the input arguments; replace commas by spaces
subjlist="${1//,/ }"

#==========================================
# Do the work (don't edit this part)
#==========================================
echo ""; echo "START: register nodif and T1 images"
echo "$(date)"; echo ""

# loop over subjects
for subj in $subjlist ; do
  echo "  monkey: $subj"

  # define the nodif and structural images
  SD=$rootdir/preprocessing/$subj
  nodif=$SD/diffusion/data/nodif
  T1=$SD/struct/struct_restore
  T1brain=$SD/struct/struct_restore_brain

  # register the nodif and T1 images
  sh $MRCATDIR/core/register_EPI_T1.sh \
    --epi=$nodif \
    --t1=$T1 \
    --t1brain=$T1brain \
    --transdir=$SD/transform \
    --all

  # define the reference images and warps
  warpfield=$SD/transform/struct_to_F99_warp
  premat=$SD/transform/nodif_to_struct.mat
  refimg=$MRCATDIR/data/macaque/F99/McLaren

  # warp the nodif(_restore) image to F99 space
  applywarp --rel --interp=spline -i $nodif -r $refimg --premat=$premat -w $warpfield -o $SD/F99/nodif
  fslmaths $SD/F99/nodif -thr 0 $SD/F99/nodif
  applywarp --rel --interp=spline -i ${nodif}_restore -r $refimg --premat=$premat -w $warpfield -o $SD/F99/nodif_restore
  fslmaths $SD/F99/nodif_restore -thr 0 $SD/F99/nodif_restore


done
echo ""; echo "END: wrapper_register_dMRI_struct"
echo "$(date)"; echo ""
