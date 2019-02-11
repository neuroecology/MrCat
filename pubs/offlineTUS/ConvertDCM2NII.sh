#!/usr/bin/env bash
umask u+rw,g+rw # give group read/write permissions to all new files
set -e    # stop immediately on error

# ------------------- #
# GENERAL DEFINITIONS
# ------------------- #
source $MRCATDIR/setupMrCat.sh
dicomDir="/Volumes/rsfMRI/anaesthesia/dicom"
origDir="/Volumes/rsfMRI/anaesthesia/orig"
instructFile=$origDir/instructConvertDCM2NII.txt

# start a timer
SECONDS=0


# ------------------------- #
# CONVERTING DICOM TO NIFTI
# ------------------------- #
# definitions
echo ""
echo "CONVERTING DICOM TO NIFTI"

# steal code from dcm2nii_general.sh
