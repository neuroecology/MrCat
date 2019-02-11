#!/usr/bin/env bash
set -e    # stop immediately on error
umask u+rw,g+rw # give group read/write permissions to all new files

# This is a simple little script to cut any volumes from a timeseries that occur
# after a detected outlier. The script is so simple, it might be helpful as a
# template script too.


# ------------------------------ #
# Help
# ------------------------------ #

usage() {
cat <<EOF

cut_outlier.sh: exclude volumes from a timeseries after an outlier is detected

example:
      sh cut_outlier.sh data errormeasure.txt --thr=5 --iqr=8
      sh cut_outlier.sh data errormeasure.txt --cutstart=0 --cutstop=639

usage: $(basename $0)
      obligatory arguments
        <data> : input data. This will be ignored when the flag --detect is set,
                 but please provide some input (e.g. "DUMMY") for consistency.
        <errormeasure> : a text file containing error measures for each volume

      optional arguments
        --thr=<abs threshold> : an absolute threshold to cut outliers above. If
              you specify --thr without --iqr the latter will be ignored.
              default: 5
        --iqr=<IQR multiplier> : a multiplier for the upper inter-quartile-range
              (from the 50th to the 75 percetile) to use as a cutoff:
              threshold = median + cutoff * uIQR.
              If you specify --iqr without --thr the latter will be ignored.
              default: 8
        --iqrlowerlimit=<IQR lower limit> : when the observed IQR is smaller
              than the value specified here, adjust the IQR multiplier (--iqr=*)
              by the square root of the ratio between the lower limit and the
              observed IQR. Please note that this value is very data-dependent.
              default: 0.05
        --cutstart : start of the good segment as a volume index (0-based).
              This overrides the cut defined by --thr and --iqr.
        --cutstop : end of the good segment as a volume index (0-based).
              This overrides the cut defined by --thr and --iqr.
        --nobackup : do not make or overwrite an back-up. Only use this option
              if you already have a backup that you wish to remain untouched.
        --detect : detect and ouput the cut values, but do not apply them
              ouput: idxOn idxOff nGood nVol
        --metric : ouput the outlier metric, scaled to the upper IQR and the
              cutoff at zero. output: nVols x 1 metric array
        --cutthr : ouput the outlier threshold
        --report : report on the outlier cuts with text, but do not apply them

EOF
}

# ------------------------------ #
# Housekeeping
# ------------------------------ #
# if no arguments given, or help is requested, return the usage
if [[ $# -eq 0 ]] || [[ $@ =~ --help ]] ; then usage; exit 0; fi

# if too few or too many arguments given, return the usage, exit with error
if [[ $# -lt 2 || $# -gt 5 ]] ; then >&2 usage; exit 1; fi

# parse the input arguments
for a in "$@" ; do
  case $a in
    -t=*|--thr=*)       cutThr="${a#*=}"; shift ;;
    -i=*|--iqr=*)       multIQR="${a#*=}"; shift ;;
    --iqrlowerlimit=*)  iqrLowerLimit="${a#*=}"; shift ;;
    --cutstart=*)       idxOn="${a#*=}"; shift ;;
    --cutstop=*)        idxOff="${a#*=}"; shift ;;
    -d|--detect)        flgCut=0; flgOutput='cutval'; shift ;;
    -m|--metric)        flgCut=0; flgOutput='metric'; shift ;;
    -c|--cutthr)        flgCut=0; flgOutput='thr'; shift ;;
    -r|--report)        flgCut=0; flgOutput='report'; shift ;;
    -n|--nobackup)      flgBackup=0; shift ;;
    *)                  arg="$arg $a"; shift ;; # ordered arguments
  esac
done

# set defaults if none specified
if [[ -z $cutThr ]] && [[ -z $multIQR ]] ; then
  cutThr=5
  multIQR=8
fi
[[ -z $cutThr ]] && cutThr=inf
[[ -z $multIQR ]] && multIQR=inf
[[ -z $iqrLowerLimit ]] && iqrLowerLimit=0.05
[[ -z $flgBackup ]] && flgBackup=1
if [[ -n $idxOn ]] || [[ -n $idxOff ]] ; then
  flgExplicitCut=1
  cutThr=inf
  multIQR=inf
  if [[ $flgOutput == "metric" ]] || [[ $flgOutput == "thr" ]] ; then
    echo "  explicit cuts specified in --cutstart/--cutstop cannot be combined with"
    echo "  --metric or --cutthr reporting options."
  fi
else
  flgExplicitCut=0
fi

# parse for obligatory arguments
# extract arguments that don't start with "-"
argobl=$(echo $arg | tr " " "\n" | grep -v '^-') || true
# parse obligatory arguments from the non-dash arguments
data=$(echo $argobl | awk '{print $1}')
err=$(echo $argobl | awk '{print $2}')

# check if obligatory arguments have been set
if [[ -z $data ]] ; then
  >&2 echo ""; >&2 echo "error: please specify the data timeseries."
  usage; exit 1
fi
[[ $flgExplicitCut -eq 1 ]] && [[ -z $err ]] && err=NA
if [[ -z $err ]] ; then
  >&2 echo ""; >&2 echo "error: please specify the error index of the timeseries."
  usage; exit 1
fi

# remove img and subjdir from list of arguments
arg=$(echo $arg | tr " " "\n" | grep -v "$data") || true
arg=$(echo $arg | tr " " "\n" | grep -v "$err") || true

# check if no redundant arguments have been set
if [[ -n $arg ]] ; then
  >&2 echo ""; >&2 echo "unsupported arguments are given:" $arg
  usage; exit 1
fi

# set default for reporting/cutting behaviour
[[ -z $flgCut ]] && flgCut=1
[[ -z $flgOutput ]] && flgOutput="report" # "report" is a dummy value


# set name of original data copy
dataDir=$(dirname $data)
base=$(basename $data)
ext=${base#*.}
[[ $ext != $base ]] && ext=".$ext" || ext=""
dataOrig=$dataDir/${base%%.*}_orig$ext

# check for original data, and restore when found
if [[ $flgCut -eq 1 ]] && [[ $flgBackup -eq 1 ]] ; then
  if [[ -r $dataOrig ]] || [[ -r $dataOrig.nii.gz ]] ; then
    echo "  backup of original timeseries found, restoring"
    immv $dataOrig $data
  fi
fi

# copy the error values to an iteration file if using a relative measure
if [[ $multIQR -ne inf ]] ; then
  # set name of iteration error copy
  errDir=$(dirname $err)
  base=$(basename $err)
  ext=${base#*.}
  [[ $ext != $base ]] && ext=".$ext" || ext=""
  errIter=$errDir/${base%%.*}_iter$ext
  errTmp=$errDir/${base%%.*}_tmp$ext
  cp $err $errIter
else
  errIter=$err
fi

# report
#echo "  data: $data"
#echo "  value: $err"

# ------------------------------ #
# Do the work
# ------------------------------ #



# determine outliers based on IQR/threshold or use excplicit cuts
if [[ $flgExplicitCut -eq 1 ]] ; then
  flgIter=FALSE
else
  flgIter=TRUE
fi

# exclude outliers, iterate until convergence when using threshold relative to IQR
idxFirst=0
while [[ $flgIter == "TRUE" ]] ; do

  # number of volumes
  nVol=$(cat $errIter | wc -l)

  # switch depending on request to use a threshold relative to the IQR
  if [[ $multIQR -ne inf ]] ; then
    # determine the upper inter-quartile-range
    med=$(sort -n $errIter | awk ' { a[i++]=$1; } END { x=int(0.5*(i+1)); if (x < 0.5*(i+1)) print (a[x-1]+a[x])/2; else print a[x-1]; }')
    prctl75=$(sort -n $errIter | awk ' { a[i++]=$1; } END { x=int(0.75*(i+1)); if (x < 0.75*(i+1)) print (a[x-1]+a[x])/2; else print a[x-1]; }')
    uIQR=$(echo $med $prctl75 | awk '{print $2-$1}')

    # adjust the multIQR when the uIQR is smaller than the specified lower limit
    multIQRAdj=$(echo $iqrLowerLimit $uIQR $multIQR | awk '{if($2<$1) n=sqrt($1/$2); else n=1; print n*$3}')

    # translate the cutoff into a threshold relative to the upper IQR
    cutIQR=$(echo $prctl75 $multIQRAdj $uIQR | awk '{print $1+($2*$3)}')
  else
    cutIQR=inf
    flgIter=FALSE
  fi

  # find the longest streak of sub-threshold error values
  idxOnOff=$(awk -v cutThr=$cutThr -v cutIQR=$cutIQR '{ if ($1<cutThr && $1<cutIQR) { if (flg) stop=NR-1; else start=NR-1; if ((stop-start)>(maxstop-maxstart)) { maxstart=start; maxstop=stop; } flg=1 } else flg=0; } END { print maxstart; print maxstop }' $errIter)
  idxOn=$(echo "$idxOnOff" | head -1)
  idxOff=$(echo "$idxOnOff" | tail -1)
  nGood=$(echo $idxOnOff | awk '{ print $2-$1+1 }')
  [[ $nGood -eq 1 ]] && nGood=0

  # break or continue
  if [[ $nGood -eq $nVol ]] || [[ $nGood -eq 0 ]] ; then
    # break iteration if converged
    flgIter=FALSE
  elif [[ $multIQR -ne inf ]] ; then
    # store cut to update
    idxFirst=$(echo $idxFirst $idxOn | awk '{ print $1 + $2}')
    awk -v idxOn=$idxOn -v idxOff=$idxOff 'FNR >= idxOn+1 && FNR <= idxOff+1 {print}' $errIter > $errTmp
    mv $errTmp $errIter
  fi

done


# determine outliers based on IQR/threshold or use excplicit cuts
if [[ $flgExplicitCut -eq 1 ]] ; then

  # number of volumes of the original data file
  nVol=$(fslnvols $dataOrig)
  [[ $nVol -eq 0 ]] && nVol=$(fslnvols $data)

  # set the volume indices (0-based) to cut
  [[ -z $idxOn ]] && idxOn=0
  [[ -z $idxOff ]] && idxOff=$((nVol-1))

  # determine the number of good volumes
  nGood=$((idxOff-idxOn+1))

else

  # remove iteration error file, if applicable
  [[ $errIter != $err ]] && rm $errIter

  # update the on- and off-sets based on the data cut
  idxOn=$(echo $idxFirst $idxOn | awk '{ print $1 + $2}')
  idxOff=$(echo $idxFirst $idxOff | awk '{ print $1 + $2}')

  # number of volumes of the original error file
  nVol=$(cat $err | wc -l)

fi


# switch depending on the requested output
if [[ $flgOutput == "cutval" ]] ; then
  # if requested to print the cut values
  echo $idxOn $idxOff $nGood $nVol
  exit 0
elif [[ $flgOutput == "metric" ]] ; then
  if [[ $multIQR -ne inf ]] ; then
    thr=$(echo $cutThr $cutIQR | awk '{if($1<$2) print $1; else print $2}')
    awk -v thr=$thr -v n=$uIQR '{print ($1-thr)/n}' $err
  else
    awk -v thr=$cutThr '{print $1-thr}' $err
  fi
  exit 0
elif [[ $flgOutput == "thr" ]] ; then
  thr=$(echo $cutThr $cutIQR | awk '{if($1<$2) print $1; else print $2}')
  if [[ $multIQR -ne inf ]] ; then
    echo $thr $uIQR
  else
    echo $thr "inf"
  fi
  exit 0
fi

# report and exclude (when applicable)
if [[ $nGood -eq $nVol ]] ; then
  echo "  no outliers"
else
  echo "  the longest streak of good volumes runs from $idxOn to $idxOff"
  if [[ $nGood -lt 100 ]] ; then
    echo "  only $nGood good continuous volumes detected (won't cut)"
  elif [[ $flgCut -eq 1 ]] ; then
    # make or leave a backup
    if [[ $flgBackup -eq 1 ]] ; then
      if [[ -r $dataOrig ]] || [[ -r $dataOrig.nii.gz ]] ; then
        echo "  backup of original timeseries found, not overwriting"
      else
        echo "  backing up the original timeseries"
        imcp $data $dataOrig
      fi
    fi
    # cut the data, if needed
    echo "  keeping only the longest streak of good volumes"
    fslroi $data $data $idxOn $nGood
  fi
fi
