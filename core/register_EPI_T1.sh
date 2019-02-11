#!/usr/bin/env bash
#ssset -e    # stop immediately on error
umask u+rw,g+rw # give group read/write permissions to all new files

#--------------------------------------------------------------------------
# Registration of functional/diffusion (EPI) to structural (T1w) images.
#
# Usage
#   type \'sh register_EPI_T1.sh\' for usage help and info
#
# version history
# 2017-11-05  Lennart   THE REAL FIX: reverted buggy fix by Rogier, pffff :)
# 2016-06-08 	Rogier    FIX: issue with $transdir that was listed as /subject/transdir
# 2016-04-06	Lennart   created
#
# copyright
# Lennart Verhagen & Rogier B. Mars
# University of Oxford & Donders Institute, 2016
#--------------------------------------------------------------------------


# ------------------------------ #
# usage
# ------------------------------ #
usage() {
cat <<EOF

Register functional/diffusion (EPI) and structural (T1w) data.

examples:
  register_EPI_T1.sh --epi=/path/to/funcdata/mean_epi
      --t1=/path/to/structdata/struct --t1brain=/path/to/structdata/struct_brain
      --segmentT1 --brainmask --biascorr --register
  register_EPI_T1.sh --epi=func --t1=struct --all

usage: register_EPI_T1.sh
  INPUT specification
  --epi=<image> : functional or nodif EPI image
  --t1=<image> : bias-corrected structural T1 image
  [--epibrainmask=<image>] : brain mask of EPI, default=<EPI image>_brain_mask
  [--t1brain=<image>] : brain extracted T1, default=<T1 image>_brain
  [--t1wm=<image>] : white matter mask of T1, default=<T1 image>_wm
  [--t1brainmask=<image>] : brain mask for T1, default=<T1 brain>_mask
  [--t1weight=<image>] : weighting image for T1, default=<T1 brain>_mask
    Please do not use the t1weight argument to provide a brain mask of the T1
    image, that is handled by the t1brain argument. This is truly for weighting
    images, and if misspecified can result in NaNs in your boundary-based reg.

  REGISTRATION arguments
  [--transdir=<dir>] : dir for transformations, default=<T1dir>/../transform
  [--dof=<val>] : registration degrees of freedom: 6 (default), 9, 12
  [--cost=<str>] : Cost funciton of the registration, default=bbr. See flirt.
  [--fmap=<image>] : fieldmap image (in rad/s), only works with 6 dof and bbr
  [--fmapmag=<image>] : fieldmap magnitude image
  [--fmapmagbrain=<image>] : fmapmag brain extracted, default=<fmapmag>_brain
  [--echospacing=<val>] : effective EPI echo spacing (dwell time) - in seconds
  [--pedir=<dir>] : phase encoding direction, dir = x/y/z/-x/-y/-z
  [--fmapreg=<TRUE/FALSE>] : perform registration of fmap to T1, default=TRUE

  INSTRUCTIONS
  [--all] : execute all instructions:
    --segmentT1 --brainmask --biascorr --brainmask --register --biascorr --register
  [--segmentT1] : segment the T1 to obtain a WM mask (skip if provided)
  [--brainmask] : create a rough brain mask for the EPI image (skip if provided)
  [--biascorr] : correct the spatial bias gradient in the EPI image
  [--register] : register the EPI and the T1 images using epi_reg

  PATHS to scripts
  [--scriptdir=<script dir>] default: <MRCATDIR/core or current directory>
    path to bet_macaque.sh and robustfov_macaque.sh scripts
  [--configdir=<config dir>] default: <MRCATDIR/config or current directory>
    path to RobustBiasCorr.sh, and default for fnirt config
EOF
}



# ------------------------------ #
# overhead
# ------------------------------ #

# if no arguments are given, or help is requested, return the usage
[[ $# -eq 0 ]] || [[ $@ =~ --help ]] && usage && exit 0

# if too few arguments given, return the usage, exit with error
[[ $# -lt 2 ]] && echo "" && >&2 echo "Error: not enough input arguments." && usage && exit 1

# if not given, retrieve directory of this script
[[ $0 == */* ]] && thisscript=$0 || thisscript="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"/$0

# if "--all" is given, run the default set
if [[ $@ =~ --all$ ]] || [[ $@ =~ "--all " ]] ; then
  # the default arguments associated with "--all"
  defaultset="--segmentT1 --brainmask --biascorr --brainmask --register --biascorr --register"
  echo "  running the complete set of instructions: $defaultset"
  # replace "--all" with the default argument set
  newargs=$(echo "${@//--all/$defaultset}")
  # execute this script with the default argument set, and passing others
  sh $thisscript $newargs
  exit 0
fi

# run each instruction on its own (with the same definitions)
definitionargs=$(echo "$@" | tr " " "\n" | grep '=') || true # enforce that the line will always have a valid exit code by adding "|| true", because grep will give an "error" exit code when empty (a problem for "set -e")
instructargs=$(echo "$@" | tr " " "\n" | grep -v '=') || true
if [[ $(echo "$instructargs" | wc -w) -gt 1 ]] ; then
  # this ensures the instructions are executed in the specified order, not in the order they are coded
  for instr in $instructargs ; do
    # run the script with one instruction, but all definitions
    sh $thisscript $definitionargs $instr
  done
  exit 0
fi

# count and grep the number of argument repetitions (ignoring after "=")
duplicates=$(echo "$@" | tr " " "\n" | awk '{ gsub("=.*","="); print $0}' | sort | uniq -c | grep -v '^ *1 ') || true   # "|| true" is added to ignore the non-zero exit code of grep (and avoid the script the stop because of "set -e")
# now test if any duplicates were found, and if so, give an error
[[ -n $duplicates ]] && >&2 echo "\nError, repetitions found in the arguments:\n$@\n${duplicates}\n" && exit 1


# ------------------------------ #
# arguments and definitions
# ------------------------------ #
# set defaults
instr=""
dof=6
costfun=bbr
flg_fmapreg=TRUE
flg_bet_epi=TRUE
[[ -n $MRCATDIR ]] && scriptdir=$MRCATDIR/core && configdir=$MRCATDIR/config

# parse the input arguments
for a in "$@" ; do
  case $a in
    --epi=*)          EPI="${a#*=}"; shift ;;
    --epibrainmask=*) EPIbrainmask="${a#*=}"; shift ;;
    --t1=*)           T1="${a#*=}"; shift ;;
    --t1brain=*)      T1brain="${a#*=}"; shift ;;
    --t1wm=*)         T1wm="${a#*=}"; shift ;;
    --t1brainmask=*)  T1brainmask="${a#*=}"; shift ;;
    --t1weight=*)     T1weight="${a#*=}"; shift ;;
    --transdir=*)     transdir="${a#*=}"; shift ;;
    --dof=*)          dof="${a#*=}"; shift ;;
    --cost=*)         costfun="${a#*=}"; shift ;;
    --fmap=*)         fmap="${a#*=}"; shift ;;
    --fmapmag=*)      fmapmag="${a#*=}"; shift ;;
    --fmapmagbrain=*) fmapmagbrain="${a#*=}"; shift ;;
    --echospacing=*)  echospacing="${a#*=}"; shift ;;
    --pedir=*)        pedir="${a#*=}"; shift ;;
    --fmapreg=*)      flg_fmapreg="${a#*=}"; shift ;;
    --scriptdir=*)    scriptdir="${a#*=}"; shift ;;
    --configdir=*)    configdir="${a#*=}"; shift ;;
    *)                instr="$instr $a"; shift ;; # instruction argument
  esac
done

# check conflicting arguments
flg_fmap=MIXED
[[ -z $fmap ]] && [[ -z $fmapmag ]] && [[ -z $echospacing ]] && [[ -z $pedir ]] && flg_fmap=FALSE
[[ -n $fmap ]] && [[ -n $fmapmag ]] && [[ -n $echospacing ]] && [[ -n $pedir ]] && flg_fmap=TRUE
if [[ $flg_fmap == MIXED ]] ; then
  >&2 echo "Error: Please provide all arguments required for the fieldmap distortion correction." && usage && exit 1
fi
[[ $flg_fmap == TRUE ]] && [[ -z $fmapmagbrain ]] && fmapmagbrain=${fmapmag}_brain
[[ $flg_fmap == TRUE ]] && [[ $dof -ne 6 ]] && >&2 echo "Error: fieldmaps can only be used with 6 dof." && usage && exit 1
[[ $flg_fmap == TRUE ]] && [[ $costfun != bbr ]] && >&2 echo "Error: fieldmaps can only be used with boundary-based register (bbr) cost." && usage && exit 1

# specify optional arguments for epi_reg
epi_reg_args=""
[[ -n $T1weight ]] && epi_reg_args="--weight=$T1weight"
[[ $flg_fmapreg == FALSE ]] && epi_reg_args="$epi_reg_args --nofmapreg"

# retrieve EPI and T1w directories
epidir=$(dirname $EPI)
structdir=$(dirname $T1)

[[ "$epidir" == "$structdir" ]] && >&2 echo "Error: please use separate folders for your EPI and T1 images to avoid mixup." && exit 1

# get target directory for transformations
[[ -z $transdir ]] && transdir="$structdir/../transform"

# remove directory and extension from filenames
EPI=$(basename $EPI)
EPI="${EPI%%.*}"
T1=$(basename $T1)
T1="${T1%%.*}"
T1base="${T1//_restore/}"
T1wm="${T1wm%%.*}"
T1wm="${T1wm%%.*}"

# retrieve or define the derivative images
[[ -n $EPIbrainmask ]] && flg_bet_epi=FALSE
[[ -z $EPIbrainmask ]] && EPIbrainmask=$epidir/${EPI}_brain_mask
[[ -z $T1brain ]] && T1brain=$structdir/${T1}_brain
[[ -z $T1wm ]] && T1wm=$structdir/${T1base}_wm
[[ -z $T1brainmask ]] && T1brainmask=$structdir/${T1base}_brain_mask
[[ $EPIbrainmask =~ / ]] || $epidir/$EPIbrainmask
[[ $T1brain =~ / ]] || $structdir/$T1brain
[[ $T1wm =~ / ]] || $structdir/$T1wm
[[ $T1brainmask =~ / ]] || $structdir/$T1brainmask

# location of MrCat scripts
if [[ -z $MRCATDIR ]] ; then
  [[ $OSTYPE == "linux-gnu" ]] && MRCATDIR="$HOME/scratch/MrCat-dev"
  [[ $OSTYPE == "darwin"* ]] && MRCATDIR="$HOME/code/MrCat-dev"
fi
# user specified locations
#[[ -z $scriptdir ]] && scriptdir="$(cd "$(dirname ${BASH_SOURCE[0]})" && pwd)"
#[[ -z $configdir ]] && configdir=$(cd $scriptdir/../config && pwd)
[[ -z $scriptdir ]] && scriptdir=$MRCATDIR/core
[[ -z $configdir ]] && configdir=$MRCATDIR/config


# ------------------------------ #
# instructions
# ------------------------------ #

# segment T1 to obtain white matter mask
if [[ $instr =~ --segmentT1$ ]] ; then

  # check if a T1 WM mask is provided
  if [[ -r $T1wm.nii.gz ]] ; then
    echo "  using provided T1 white matter mask"

  else
    echo "  T1 segmentation"

    # initialise a temporary working directory
    workdir=$(mktemp -d "$structdir/tmp_segment.XXXXXXXXXX")
    mkdir -p $workdir
    imcp $T1brain $workdir/${T1}_brain

    # segment the T1, without extra biascorrection
    fast -n 3 -t 1 -g --nobias $workdir/${T1}_brain
    immv $workdir/${T1}_brain_seg_2 $T1wm

    # remove workdir
    rm -rf $workdir
  fi
  echo "    done"
fi


# create a brain mask for the EPI image
if [[ $instr =~ --brainmask$ ]] ; then

  # make a new epi brain mask if needed
  if [[ $flg_bet_epi == TRUE ]] || [[ ! -r $EPIbrainmask.nii.gz ]] ; then

    # use a restored image, if present
    [[ -r $epidir/${EPI}_restore.nii.gz ]] && EPI=${EPI}_restore

    # initialise a temporary working directory
    workdir=$(mktemp -d "$epidir/tmp_brainmask.XXXXXXXXXX")
    mkdir -p $workdir

    # create a brain mask of the EPI image
    $scriptdir/bet_macaque.sh $epidir/$EPI $workdir/$EPI -t T2star --refine #-f 0.5 -fFP 0.9 -fTP 0.9
    immv $workdir/${EPI}_brain_mask $EPIbrainmask

    # remove the workdir, and a potential strict mask (that is no longer valid)
    rm -rf $workdir
    imrm ${EPIbrainmask}_strict

  else
      echo "  using provided EPI_brain_mask"
  fi

fi


# bias correction of the EPI image
if [[ $instr =~ --biascorr$ ]] ; then
  echo "  bias correction of the EPI image"

  # cut out the bright spots to make the bias-correction more robust
  if [[ ! -r ${EPIbrainmask}_strict.nii.gz ]] ; then
    thr=$(fslstats $epidir/$EPI -k $EPIbrainmask -P 95)
    fslmaths $epidir/$EPI -s 2 -thr $thr -binv -mas $EPIbrainmask ${EPIbrainmask}_strict
  fi

  # initialise a temporary working directory
  workdir=$(mktemp -d "$epidir/tmp_biascorr.XXXXXXXXXX")
  mkdir -p $workdir

  # smoothness definitions
  sigma=3 #acquisition protocol dependent
  FWHM=$(echo "2.3548 * $sigma" | bc)

  # run robust bias correction on the EPI
  $scriptdir/RobustBiasCorr.sh \
    --in=$epidir/$EPI \
    --workingdir=$workdir \
    --brainmask=${EPIbrainmask}_strict \
    --basename=$EPI \
    --FWHM=$FWHM \
    --type=2 \
    --forcestrictbrainmask="FALSE" --ignorecsf="FALSE"

  # copy the restored image and bias field
  imcp $workdir/${EPI}_restore $epidir/${EPI}_restore
  imcp $workdir/${EPI}_bias $epidir/${EPI}_bias

  # remove the workdir
  rm -rf $workdir

  echo "    done"
fi


# register the bias corrected EPI image to the T1
if [[ $instr =~ --register$ ]] ; then

  # make the transformation directory (if it doesn't exist)
  mkdir -p $transdir

  # if a fieldmap is provided, make sure a brain map exists
  if [[ $flg_fmap == TRUE ]] && [[ ! -r $fmapmagbrain.nii.gz ]]; then
    # use a brain mask either from the EPI, or from the T1
    if [[ $flg_fmapreg == TRUE ]] ; then
      fslmaths $fmapmag -mas $EPIbrainmask $fmapmagbrain
    else
      # initialise a temporary working directory
      workdir=$(mktemp -d "$structdir/tmp_fieldmapmask.XXXXXXXXXX")
      mkdir -p $workdir
      # resample the T1 brain mask to the field map
      flirt -in $T1brainmask -ref $fmapmag -applyxfm -init $FSLDIR/etc/flirtsch/init.mat -out $workdir/brainmask
      fslmaths $fmapmag -mas $workdir/brainmask $fmapmagbrain
      # remove the workdir
      rm -rf $workdir
    fi
  fi

  # use a restored image, if present
  EPIbase=$EPI
  [[ -r $epidir/${EPI}_restore.nii.gz ]] && EPI=${EPI}_restore

  # cut out the bright spots of the brain mask to make the registration more robust
  if [[ ! -r ${EPIbrainmask}_strict.nii.gz ]] ; then
    thr=$(fslstats $epidir/$EPI -k $EPIbrainmask -P 95)
    fslmaths $epidir/$EPI -s 2 -thr $thr -binv -mas $EPIbrainmask ${EPIbrainmask}_strict
  fi

  # extract the EPI brain
  fslmaths $epidir/$EPI -mas ${EPIbrainmask}_strict $epidir/${EPI}_brain

  # define transformation matrices
  regfwd=$transdir/${EPIbase}_to_${T1base}
  reginv=$transdir/${T1base}_to_${EPIbase}

  # and now register the EPI image to the T1 image using epi_reg or bbr flirt
  if [[ $costfun == bbr ]] ; then

    if [[ $dof -eq 6 ]] ; then
      echo "  rigid-body registration of the EPI to the T1 image using epi_reg"
      # is a field map provided?
      if [[ $flg_fmap == TRUE ]] ; then
        epi_reg --epi=$epidir/${EPI}_brain --t1=$structdir/$T1 --t1brain=$T1brain --wmseg=$T1wm --out=$regfwd --fmap=$fmap --fmapmag=$fmapmag --fmapmagbrain=$fmapmagbrain --echospacing=$echospacing --pedir=$pedir $epi_reg_args
      else
        epi_reg --epi=$epidir/${EPI}_brain --t1=$structdir/$T1 --t1brain=$T1brain --wmseg=$T1wm --out=$regfwd $epi_reg_args
      fi
    else
      echo "  initial linear registration ($dof dof) of the EPI to the T1 image"
      flirt -dof $dof -in $epidir/${EPI}_brain -inweight ${EPIbrainmask}_strict -ref $T1brain -refweight $T1brainmask -omat $regfwd.mat
      echo "  refined linear boundary-based registration ($dof dof) of the EPI to the T1 image"
      flirt -dof $dof -cost bbr -init $regfwd.mat -in $epidir/${EPI}_brain -inweight ${EPIbrainmask}_strict -ref $T1brain -wmseg $T1wm -omat $regfwd.mat
    fi
  else

    echo "  linear registration ($dof dof, $costfun cost) of the EPI to the T1 image"
    flirt -dof $dof -cost $costfun -in $epidir/${EPI}_brain -inweight ${EPIbrainmask}_strict -ref $T1brain -refweight $T1brainmask -omat $regfwd.mat
  fi

  # report cost value
  costval=$(flirt -ref $T1brain -in $epidir/${EPI}_brain -schedule $FSLDIR/etc/flirtsch/measurecost1.sch -init ${regfwd}.mat | head -1 | cut -d' ' -f1)
  echo "    cost value: $costval"
  [[ $(echo $cost | awk '($1>0.9){print 1}') ]] && echo "    The linear registration seems to have failed." && echo "    Please check your input images and the WM segmentation."

  echo "  invert the matrix and clean-up"
  # invert the matrix and clean-up
  convert_xfm -omat $reginv.mat -inverse $regfwd.mat
  immv $regfwd $structdir/$EPI
  rm ${regfwd}_*

  echo "  transform structural images to EPI space"
  # delete obsolete EPI based brain masks
  imrm $epidir/${EPIbase}_brain_mask $epidir/${EPIbase}_brain_mask_strict
  # transform the structural image to the EPI space
  applywarp --rel --interp=spline -i $structdir/$T1 -r $epidir/$EPI --premat=$reginv.mat -o $epidir/$T1
  fslmaths $epidir/$T1 -thr 0 $epidir/$T1
  # transform the brain masks to the EPI space
  T1basebrainmask="$(basename $T1brainmask)"
  applywarp --rel --interp=nn -i $T1brainmask -r $epidir/$EPI --premat=$reginv.mat -o $epidir/$T1basebrainmask
  [[ -r ${T1brainmask}_strict.nii.gz ]] && applywarp --rel --interp=nn -i ${T1brainmask}_strict -r $epidir/$EPI --premat=$reginv.mat -o $epidir/${T1basebrainmask}_strict
  imcp $epidir/$T1basebrainmask $epidir/${EPIbase}_brain_mask
  imcp $epidir/${T1basebrainmask}_strict $epidir/${EPIbase}_brain_mask_strict
  # mask the structural image
  fslmaths $epidir/$T1 -mas $epidir/$T1basebrainmask $epidir/${T1}_brain

  echo "    done"
fi
