#!/usr/bin/env bash
set -e    # stop immediately on error
umask u+rw,g+rw # give group read/write permissions to all new files

# This is template script for a simple fixed processing pipeline


# ------------------------------ #
# Help
# ------------------------------ #

usage() {
cat <<EOF

rsn_swapdim.sh: Swap the data dimensions of an image according to macaque standard

example:
      sh rsn_swapdim.sh image.nii.gz <A> <B> <C>

        where a,b,c represent the new x,y,z axes in terms of the
        old axes.  They can take values of -x,x,y,-y,z,-z
        or RL,LR,AP,PA,SI,IS (in the case of nifti inputs)
        e.g.  rsn_swapdim.sh invol y x -z
        or    rsn_swapdim.sh invol RL PA IS
        where the latter will convert to axial slicing
        (to match the avg152 images)

usage: $(basename $0)
      obligatory arguments
        <input image> : the input image to process
        <A> : old axis on first dimension
        <B> : old axis on second dimension
        <C> : old axis on third dimension

EOF
}


# ------------------------------ #
# Housekeeping
# ------------------------------ #

# if no arguments given, or help is requested, return the usage
if [[ $# -eq 0 ]] || [[ $@ =~ --help ]] ; then usage; exit 0; fi
# if too few or too many arguments are given, return the usage, exit with error
if [[ $# -ne 4 ]] ; then >&2 usage; exit 1; fi

# parse obligatory arguments from the non-dash arguments
img="$1"
A="$2"
B="$3"
C="$4"

# check if obligatory arguments have been set
if [[ -z $img ]] ; then >&2 echo ""; >&2 echo "error: please specify the input image."; usage; exit 1; fi
if [[ -z $C ]] ; then >&2 echo ""; >&2 echo "error: please specify axis-dimension mapping"; usage; exit 1; fi


# ------------------------------ #
# Do the work
# ------------------------------ #

fslorient -deleteorient $img
fslswapdim $img $A $B $C $img #&>/dev/null
fslorient -setqformcode 1 $img
fslorient -forceradiological $img
