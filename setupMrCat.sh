#!/usr/bin/env bash
umask u+rw,g+rw # give group read/write permissions to all new files

# parse the input arguments
flgPurge="FALSE"
for a in "$@" ; do
  case $a in
    -f|--force|--purge)   flgPurge="TRUE"; shift ;;
    -e=*|--example=*)     example="${a#*=}"; shift ;;
    *)                    unknown="$unknown $a"; shift ;; # unknown arguments
  esac
done

# if a purge is requested, ensure that the environment variables are empty
if [[ $flgPurge == "TRUE" ]] ; then
  MRCATDIR=""
  MATLABBIN=""
  HCPDATADIR=""
  WBBIN=""
  LOGDIR=""
  RUN=""
  RUNVERYSHORT=""
  RUNSHORT=""
  RUNLONG=""
  RUNVERYLONG=""
  RUNBIGMEM=""
fi


#---------------------------------------
# Set environment variables
#---------------------------------------

# dependent on operating system
#---------------------------------------
if [[ $OSTYPE == "darwin"* ]] ; then
  # when running on macOS

  # MrCat directory
  #---------------------------------------
  [[ -z $MRCATDIR ]] && MRCATDIR="$HOME/code/MrCat-dev"

  # FSL directory directory
  #---------------------------------------
  if [[ -z $FSLDIR ]] ; then
    FSLDIR=/usr/local/fsl
    PATH=${FSLDIR}/bin:${PATH}
    . ${FSLDIR}/etc/fslconf/fsl.sh
  fi

  # Matlab binary directory
  #---------------------------------------
  # get all matlab versions in /Applications
  matlabdir=($(echo /Applications/MATLAB_R20*))
  # retrieve only the latest version
  matlabdir=${matlabdir[${#matlabdir[@]}-1]}
  # and retrieve the binaries
  [[ -z $MATLABBIN ]] && MATLABBIN=$matlabdir/bin

  # HCP data directory does not exist locally
  #---------------------------------------
  [[ -z $HCPDATADIR ]] && HCPDATADIR=""

  # local job running commands
  #---------------------------------------
  [[ -z $RUN ]] && RUN=""
  [[ -z $LOGDIR ]] && LOGDIR="./log"
  [[ -z $RUNVERYSHORT ]] && RUNVERYSHORT=""
  [[ -z $RUNSHORT ]] && RUNSHORT=""
  [[ -z $RUNLONG ]] && RUNLONG=""
  [[ -z $RUNVERYLONG ]] && RUNVERYLONG=""
  [[ -z $RUNBIGMEM ]] && RUNBIGMEM=""


elif [[ $OSTYPE == "linux-gnu" ]] ; then
  # when running on Linux

  # MrCat directory
  #---------------------------------------
  [[ -z $MRCATDIR ]] && MRCATDIR="$HOME/scratch/MrCat-dev"

  # FSL directory
  #---------------------------------------
  if [[ -z $FSLDIR ]] ; then
    FSLDIR=/opt/fmrib/fsl
    PATH=${FSLDIR}/bin:${PATH}
    . ${FSLDIR}/etc/fslconf/fsl.sh
  fi

  # Matlab binary directory
  #---------------------------------------
  #MATLABBIN=/opt/fmrib/bin/
  [[ -z $MATLABBIN ]] && MATLABBIN=/opt/fmrib/MATLAB/R2016a/bin

  # HCP data directory
  #---------------------------------------
  [[ -z $HCPDATADIR ]] && HCPDATADIR=/vols/Scratch/HCP

  # environment modules
  #---------------------------------------
  # ensure that the HCP specific version of FreeSurfer is being used
  module add freesurfer/5.3.0-HCP > /dev/null 2>&1 # (don't say a peep)
  # ensure that the correct version of workbench (wrapper) is used
  module add workbench
  # pre-2017 way to do this: module load freesurfer-5.3.0-HCP > /dev/null 2>&1 # (don't say a peep)
  # you can revert back using: module swap freesurfer-5.3.0-HCP freesurfer > /dev/null 2>&1 # (don't say a peep)

  # jalapeno cluster job running commands
  #---------------------------------------
  [[ -z $RUN ]] && RUN="fsl_sub"
  [[ -z $LOGDIR ]] && LOGDIR="./log"
  [[ -z $RUNVERYSHORT ]] && RUNVERYSHORT="fsl_sub -q veryshort.q -l $LOGDIR"
  [[ -z $RUNSHORT ]] && RUNSHORT="fsl_sub -q short.q -l $LOGDIR"
  [[ -z $RUNLONG ]] && RUNLONG="fsl_sub -q long.q -l $LOGDIR"
  [[ -z $RUNVERYLONG ]] && RUNVERYLONG="fsl_sub -q verylong.q -l $LOGDIR"
  [[ -z $RUNBIGMEM ]] && RUNBIGMEM="fsl_sub -q bigmem.q -l $LOGDIR"

fi


# Workbench binary directory
#---------------------------------------
[[ -z $WBBIN ]] && WBBIN="$(dirname "$(which wb_command)")"
[[ -z $WBBIN ]] && WBBIN="$CARET7DIR"
[[ -z $WBBIN ]] && >&2 echo "please provide the binary directory for Workbench" && exit 1

# FreeSurfer uses FSL_DIR instead of FSLDIR to determine the FSL version
#---------------------------------------
FSL_DIR="${FSLDIR}"


# flag that setup is finished
#---------------------------------------
SETUPMRCAT="TRUE"


# make variables available in the environment
#---------------------------------------
export PATH MRCATDIR FSLDIR FSL_DIR MATLABBIN HCPDATADIR WBBIN LOGDIR RUN RUNVERYSHORT RUNSHORT RUNLONG RUNVERYLONG RUNBIGMEM SETUPMRCAT
