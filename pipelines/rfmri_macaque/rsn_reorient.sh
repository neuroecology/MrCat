#!/usr/bin/env bash
set -e    # stop immediately on error
umask u+rw,g+rw # give group read/write permissions to all new files

# Reorient an image according to macaque standard


# ------------------------------ #
# Help
# ------------------------------ #

usage() {
cat <<EOF

rsn_reorient.sh: Reorient an image according to macaque standard

example:
      sh rsn_reorient.sh image.nii.gz
      sh rsn_reorient.sh image.nii.gz --method=orient
      sh rsn_reorient.sh image.nii.gz -f

usage: $(basename $0)
      obligatory arguments
        <input image>     the input image to process
      optional arguments
        --method=<orient|standard|swapdim>
                          set the method: orient (default), standard, swapdim
        -f,--force        force to redo the reorientation, even if done before

EOF
}


# ------------------------------ #
# Housekeeping
# ------------------------------ #

# if no arguments given, or help is requested, return the usage
if [[ $# -eq 0 ]] || [[ $@ =~ --help ]] ; then usage; exit 0; fi
# if too few arguments given, return the usage, exit with error
if [[ $# -lt 1 ]] ; then >&2 usage; exit 1; fi

# parse the input arguments
#------------------------------
for a in "$@" ; do
  case $a in
    -m=*|--method=*)    flgMethod="${a#*=}"; shift ;;
    -f|--force)         flgForce=1; shift ;;
    *)                  arg="$arg $a"; shift ;; # ordered arguments
  esac
done

# parse for obligatory arguments
#------------------------------
# extract arguments that don't start with "-"
argobl=$(echo $arg | tr " " "\n" | grep -v '^-') || true
# parse obligatory arguments from the non-dash arguments
img=$(echo $argobl | awk '{print $1}')
# check if obligatory arguments have been set
if [[ -z $img ]] ; then >&2 echo ""; >&2 echo "error: please specify the input image."; usage; exit 1; fi
# remove img from list of arguments
arg=$(echo $arg | tr " " "\n" | grep -v "$img") || true
# check if no redundant arguments have been set
if [[ -n $arg ]] ; then >&2 echo ""; >&2 echo "unsupported arguments are given: $arg"; usage; exit 1; fi

# set defaults for optional arguments
#------------------------------
[[ -z $flgMethod ]] && flgMethod="orient"
[[ -z $flgForce ]] && flgForce=0


# ------------------------------ #
# Do the work
# ------------------------------ #

# define the logfile
workDir=$(dirname $img)
logFile=$workDir/reorient.log

# if requested to force the reorientation, remove the logfile
[[ $flgForce -eq 1 ]] && rm -f $logfile

# give a warning if the logfile suggest the reorientation has been done already
# otherwise, reorient
if [[ -s $logFile ]] && [[ $(cat $logFile) =~ done ]] ; then

  echo "    The logfile suggests the data has already been reoriented"
  echo "    If you want to reorient again, please use the -f,--force option"
  echo "    or remove the logfile:"
  echo "      $logFile"

else

  # initialise a logfile
  printf "reorient method:\n  %s\n\n" $flgMethod > $logFile

  # reorient, based on specified methods
  case $flgMethod in
    orient )
      fslorient -deleteorient $img 2>&1 | tee -a $logFile
      fslorient -setqformcode 1 $img 2>&1 | tee -a $logFile
      fslorient -forceradiological $img 2>&1 | tee -a $logFile
      ;;
    standard )
      fslreorient2std $img $img 2>&1 | tee -a $logFile
      ;;
    swapdim )
      sh $MRCATDIR/pipelines/rfmri_macaque/rsn_swapdim.sh $img -x z y 2>&1 | tee -a $logFile
      ;;
    * )
      >&2 printf "\nUnsupported method: %s\n\n" $flgMethod
      >&2 usage
      exit 1
      ;;
  esac

  # mark the success of the reorientation in the logfile
  printf "\ndone\n" >> $logFile

fi
