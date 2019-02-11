#!/usr/bin/env bash
set -e    # stop immediately on error

# ------------------------------ #
# usage
# ------------------------------ #

usage() {
cat <<EOF

bet_macaque.sh: brain extraction tailored for macaque brains

Usage:    sh bet_macaque.sh <input> [<output>] [options]

Example:  sh bet_macaque.sh nodif -t T2star -f 0.5 -fFP 0.9 -fTP 0.9

Main bet_macaque options:
  <input>     input image, obligatory
  <output>    base name of the output image, <input> is taken when not specified

Options specifically tailored for bet_macaque:
  -t <type>   type of image: "T1" (default), "T2star". "T2" is not yet supported. Determines parameter defaults.
  -s <size>   method to estimate the brain size. Choose from: "int"(ensity) (default), "bet", or give the <back to front distance in mm>. For the last option 70 is a good guess.
  -f <f>      fractional intensity threshold (0->1); smaller values give larger brain outline estimates; T1 default=0.2; T2star default=0.5
  -fFP <f>    frontal pole fractional intensity threshold (0->1); T1 default=0.6; T2star default=0.7
  -fTP <f>    temporal pole fractional intensity threshold (0->1); T1 default=0.3; T2star default=0.8
  -r <r>      head radius (mm not voxels); default=30; initial surface sphere is set to middle of this
  -rFP <r>    frontal pole radius (mm not voxels); default=25
  -rTP <r>    temporal pole radius (mm not voxels); default=25
  -n <niter>  number of iterations; default=10
  -t <tol>    tolerance for convergence over iterations; default=500mm^3
  -m          create only the mask, not the brain extracted image
  -d          debug mode: do not remove intermediate images

Please note that all other options of the conventional bet2 have been pre-set.

EOF
}


#==============================
# overhead, argument parsing
#==============================

# if no arguments given, return the usage
if [[ $# -eq 0 ]] ; then usage; exit 0; fi

# if too few arguments given, return the usage, exit with error
if [[ $# -lt 1 ]] ; then >&2 usage; exit 1; fi

# set global defaults
args=""
imgtype=T1
size=int
rbrain=30
rFP=25
rTP=25
niter=10
tol=500
flgmaskonly=FALSE
flgdebug=FALSE
flgRefine=FALSE

# parse the input arguments
while [[ $# -gt 0 ]] ; do
  case "$1" in
      -t|--type)    imgtype="$2"; shift 2 ;;
      -s|--size)    size="$2";    shift 2 ;;
      -f|--fbrain)  fbrain="$2";  shift 2 ;;
      -fFP|--fFP)   fFP="$2";     shift 2 ;;
      -fTP|--fTP)   fTP="$2";     shift 2 ;;
      -r|--rbrain)  rbrain="$2";  shift 2 ;;
      -rFP|--rFP)   rFP="$2";     shift 2 ;;
      -rTP|--rTP)   rTP="$2";     shift 2 ;;
      -n|--niter)   niter="$2";   shift 2 ;;
      -t|--tol)     tol="$2";     shift 2 ;;
      --refine)     flgRefine=TRUE; shift ;;
      -m|--maskonly) flgmaskonly=TRUE; shift ;;
      -d|--debug)   flgdebug=TRUE; shift ;;
      *) args=$(echo "$args" "$1"); shift ;; # either obligatory or unknown option
  esac
done

# accept <size> "intensity" as meaning "int"
[[ $size == intensity ]] && size=int

# set defaults based on image type
case $imgtype in
  T1)
    [[ -z $fbrain ]] && fbrain=0.2
    [[ -z $fFP ]] && fFP=$(echo $fbrain 0.6 | awk '{$1+=0.2; if ($1>$2) print $1; else print $2}')
    [[ -z $fTP ]] && fTP=$(echo $fbrain 0.3 | awk '{$1+=0.1; if ($1>$2) print $1; else print $2}')
    [[ $size == int ]] && vol=200000
    ;;
  T2star)
    [[ -z $fbrain ]] && fbrain=0.5
    [[ -z $fFP ]] && fFP=$(echo $fbrain 0.7 | awk '{$1+=0.2; if ($1>$2) print $1; else print $2}')
    [[ -z $fTP ]] && fTP=$(echo $fbrain 0.8 | awk '{$1+=0.3; if ($1>$2) print $1; else print $2}')
    [[ $size == int ]] && vol=100000
    ;;
  *) >&2 echo "unrecognized image type: $imgtype"; exit 1 ;;
esac

# flags if a frontal and temporal pole centroid needs to be run
flgFP=$(echo $fFP | awk '{if($1<1) print "true"; else print "false"}')
flgTP=$(echo $fTP | awk '{if($1<1) print "true"; else print "false"}')

# parse for obligatory arguments
# extract arguments that don't start with "-"
argsobl=$(echo $args | tr " " "\n" | grep -v '^-') || true
# parse obligatory arguments from the non-dash arguments
img=$(echo $argsobl | awk '{print $1}')
base=$(echo $argsobl | awk '{print $2}')

# check if obligatory arguments have been set
if [[ -z $img ]] ; then
  >&2 echo ""; >&2 echo "error: please specify the input image."
  usage; exit 1
fi
[[ -z $base ]] && base="$img"

# remove img and base from list of arguments
args=$(echo $args | tr " " "\n" | grep -v "$img") || true
args=$(echo $args | tr " " "\n" | grep -v "$base") || true

# check if no redundant arguments have been set
if [[ -n $args ]] ; then
  >&2 echo ""; >&2 echo "unsupported arguments are given:" $args
  usage; exit 1
fi

# remove extension
[[ $img =~ / ]] && imgpath="${img%/*}" || imgpath="."
img="${img##*/}"
img=$imgpath/"${img%%.*}"
[[ $base =~ / ]] && basepath="${base%/*}" || basepath="."
base="${base##*/}"
base=$basepath/"${base%%.*}"


#==============================
# run the 'refine' protocol
#==============================
if [[ $flgRefine == TRUE ]] ; then

  # set the debug option
  [[ $flgdebug == "TRUE" ]] && optDebug=" --debug" || optDebug=""

  # create a tmp directory to calculate the sMAPE in the brain
  tmpDir=$(mktemp -d "$imgpath/tmp.bet_macaque_refine.XXXXXXXXXX")

  # copy the image to the tmp directory
  imcp $img $tmpDir/img

  # brain extract the image
  echo "  creating a conservative brain mask"
  $MRCATDIR/core/bet_macaque.sh $tmpDir/img -t $imgtype -m -n $((niter/2)) $optDebug

  # erode to be conservative
  fslmaths $tmpDir/img_brain_mask -ero -ero $tmpDir/img_brain_mask_strict

  # ignore dark voxels
  thr=$(fslstats $tmpDir/img -k $tmpDir/img_brain_mask_strict -P 50 | awk '{print $1/4}')
  fslmaths $tmpDir/img -mas $tmpDir/img_brain_mask -thr $thr -bin $tmpDir/img_brain_mask_strict
  cluster --in=$tmpDir/img_brain_mask_strict --thresh=0.5 --connectivity=6 --minextent=10000 --no_table --oindex=$tmpDir/img_brain_mask_strict
  fslmaths $tmpDir/img_brain_mask_strict -bin -s 2 -thr 0.6 -bin -mas $tmpDir/img_brain_mask $tmpDir/img_brain_mask_strict
  # and the super bright
  thr=$(fslstats $tmpDir/img -k $tmpDir/img_brain_mask_strict -P 99.8)
  fslmaths $tmpDir/img -uthr $thr -mas $tmpDir/img_brain_mask_strict -bin $tmpDir/img_brain_mask_strict

  # smoothness definitions
  sigma=3 #acquisition protocol dependent
  FWHM=$(echo "2.3548 * $sigma" | bc)

  # define image type
  [[ $imgtype == "T1" ]] && T=1 || T=2

  # run robust bias correction on the EPI
  sh $MRCATDIR/core/RobustBiasCorr.sh \
    --in=$tmpDir/img \
    --workingdir=$tmpDir/biascorr \
    --brainmask=$tmpDir/img_brain_mask_strict \
    --FWHM=$FWHM \
    --type=$T \
    --forcestrictbrainmask="FALSE" \
    --ignorecsf="FALSE"

  # clean up
  immv $tmpDir/biascorr/img_restore $tmpDir/img_restore
  rm -rf $tmpDir/biascorr

  # brain extract the bias-corrected image
  echo "  brain extracting the bias-corrected image"
  $MRCATDIR/core/bet_macaque.sh $tmpDir/img_restore -t $imgtype -m -n $niter $optDebug
  immv $tmpDir/img_restore_brain_mask $tmpDir/img_brain_mask

  # erode to be conservative
  echo "  refining the brain mask"
  fslmaths $tmpDir/img_brain_mask -ero -ero $tmpDir/img_brain_mask_strict

  # ignore dark voxels and smooth mildly
  thr=$(fslstats $tmpDir/img_restore -k $tmpDir/img_brain_mask_strict -P 50 | awk '{print $1/4}')
  fslmaths $tmpDir/img_restore -mas $tmpDir/img_brain_mask -thr $thr -bin $tmpDir/img_brain_mask_strict
  cluster --in=$tmpDir/img_brain_mask_strict --thresh=0.5 --connectivity=6 --minextent=10000 --no_table --oindex=$tmpDir/img_brain_mask_strict
  fslmaths $tmpDir/img_brain_mask_strict -bin -fillh -s 2 -thr 0.4 -bin -mas $tmpDir/img_brain_mask $tmpDir/img_brain_mask
  thr=$(fslstats $tmpDir/img_restore -k $tmpDir/img_brain_mask -P 50 | awk '{print $1/4}')
  fslmaths $tmpDir/img_restore -mas $tmpDir/img_brain_mask -thr $thr -bin -fillh -s 1.5 -thr 0.45 -bin -mas $tmpDir/img_brain_mask $tmpDir/img_brain_mask

  # create a strict (unsmoothed) brain mask without any dark voxels
  fslmaths $tmpDir/img_brain_mask -ero $tmpDir/img_brain_mask_strict
  thr=$(fslstats $tmpDir/img_restore -k $tmpDir/img_brain_mask_strict -P 50 | awk '{print $1/2}')
  fslmaths $tmpDir/img_restore -mas $tmpDir/img_brain_mask -thr $thr -bin $tmpDir/img_brain_mask_strict
  cluster --in=$tmpDir/img_brain_mask_strict --thresh=0.5 --connectivity=6 --minextent=10000 --no_table --oindex=$tmpDir/img_brain_mask_strict
  fslmaths $tmpDir/img_brain_mask_strict -bin -s 2 -thr 0.45 -bin -mas $tmpDir/img_brain_mask_strict $tmpDir/img_brain_mask_strict2

  # move/rename brain mask to requested output
  immv $tmpDir/img_brain_mask ${base}_brain_mask
  immv $tmpDir/img_brain_mask_strict ${base}_brain_mask_strict

  # apply the brain mask
  [[ $flgmaskonly != TRUE ]] && fslmaths $img -mas ${base}_brain_mask ${base}_brain

  # clean up
  [[ $flgdebug != TRUE ]] && rm -rf $tmpDir

  # return
  exit 0

fi


#==============================
# main code
#==============================

echo "  brain extraction of: $img"

# loop until desired iterations or convergence
c=0
while [[ $c -lt $niter ]] ; do
  [[ $niter -gt 1 ]] && echo "    iteration: $((c+1))"

  # switch between different methods to determine the brain size
  case $size in
    bet)
      # run bet to get an initial brain mask
      if [[ $c -eq 0 ]] ; then
        bet $img ${base}_brain -m -n -r $rbrain -f $fbrain
        [[ $flgdebug == TRUE ]] && imcp ${base}_brain_mask ${base}_init_mask
      fi
      # retrieve centriod
      str=$(fslstats ${base}_brain_mask -C -w)
      xmid=$(echo $str | awk '{print $1}')
      ymid=$(echo $str | awk '{print $2}')
      zmid=$(echo $str | awk '{print $3}')
      # and one more superior centroid
      zsup=$(echo $str | awk '{print $3+$9*0.15}')
      # add posterior and anterior centroids
      ypost=$(echo $str | awk '{print $2-$7*0.2}')
      yant=$(echo $str | awk '{print $2+$7*0.2}')
      ;;
    int)
      # find a robust percentage of voxels belonging to the head (200000 mm^2)
      dx=$(fslval $img pixdim1)
      dy=$(fslval $img pixdim2)
      dz=$(fslval $img pixdim3)
      nvox=$(fslhd -x $img | grep "nvox = " | tr -d "[:alpha:][:space:][:punct:]")
      p=$(echo $dx $dy $dz $nvox $vol | awk '{print 100-(100*$5/($1*$2*$3*$4))}')
      # find a robust extend of the head
      thr=$(fslstats $img -p $p)
      fslmaths $img -thr $thr -bin -s 6 -thr 0.4 -bin ${base}_brain_mask
      [[ $flgdebug == TRUE ]] && imcp ${base}_brain_mask ${base}_init_mask
      # retrieve centriod
      str=$(fslstats ${base}_brain_mask -C -w)
      xmid=$(echo $str | awk '{print $1}')
      ymid=$(echo $str | awk '{print $2}')
      zmid=$(echo $str | awk '{print $3}')
      # and one more superior centroid
      zsup=$(echo $str | awk '{print $3+$9*0.2}')
      # add posterior and anterior centroids
      ypost=$(echo $str | awk '{print $2-$7*0.2}')
      yant=$(echo $str | awk '{print $2+$7*0.2}')
      ;;
    *)
      # find the image dimensions
      xdim=$(fslval $img dim1)
      ydim=$(fslval $img dim2)
      zdim=$(fslval $img dim3)
      dx=$(fslval $img pixdim1)
      dy=$(fslval $img pixdim2)
      dz=$(fslval $img pixdim3)
      # find sensible centroid to initialise bet
      xmid=$(echo $xdim | awk '{print $1/2}')
      ymid=$(echo $ydim | awk '{print $1/2}')
      zmid=$(echo $zdim | awk '{print $1/2}')
      # and one more superior centroid
      zsup=$(echo $zmid $dz $size | awk '{print $1+($3/(12*$2))}')
      # add posterior and anterior controids, based on provided size
      ypost=$(echo $ymid $dy $size | awk '{print $1-($3/(4*$2))}')
      yant=$(echo $ymid $dy $size | awk '{print $1+($3/(4.5*$2))}')
      ;;
  esac

  # run bet centred at an anterior position
  [[ -z $zsup ]] && zsup=$zmid
  bet $img ${base}_brain_ant -m -n -r $rbrain -f $fbrain -c $xmid $yant $zsup
  # and once more at a central (default) position
  bet $img ${base}_brain -m -n -r $rbrain -f $fbrain -c $xmid $ymid $zmid
  # and once more at a posterior position
  bet $img ${base}_brain_post -m -n -r $rbrain -f $fbrain -c $xmid $ypost $zmid

  # add them and binarise
  fslmaths ${base}_brain_mask -add ${base}_brain_ant_mask -add ${base}_brain_post_mask -bin ${base}_brain_mask

  # find the extent of the brain mask
  str=$(fslstats ${base}_brain_mask -C -w)

  # run an additional frontal pole bet (or not)
  if [[ $flgFP == true ]] ; then
    # extract coordinates for frontal pole centroid
    x=$(echo $str | awk '{print $1}')
    y=$(echo $str | awk '{print $2+$7*3/8}')
    z=$(echo $str | awk '{print $3+$9/12}')

    # frontal pole bet
    bet $img ${base}_Fpole -m -r $rFP -f $fFP -c $x $y $z

    # make sure the mask is not all ones (replace by zeros if they are)
    [[ $(fslstats ${base}_Fpole_mask -R | awk '($1==$2){print "TRUE"}') == TRUE ]] && fslmaths ${base}_Fpole_mask -mul 0 ${base}_Fpole_mask
  fi

  # run an additional temporal pole bet (or not)
  if [[ $flgTP == true ]] ; then
    # extract coordinates for temporal pole centroid
    xL=$(echo $str | awk '{print $1-$5*2/7}')
    xR=$(echo $str | awk '{print $1+$5*2/7}')
    #y=$(echo $str | awk '{print $2+$7/8}')
    y=$(echo $str | awk '{print $2+$7/7}')
    z=$(echo $str | awk '{print $3-$9*2/6}')

    # temporal poles bet
    bet $img ${base}_TpoleL -m -n -r $rTP -f $fTP -c $xL $y $z
    bet $img ${base}_TpoleR -m -n -r $rTP -f $fTP -c $xR $y $z

    # make sure the masks are not all ones (replace by zeros if they are)
    for TPmask in ${base}_TpoleL_mask ${base}_TpoleR_mask ; do
      # count the proportion of voxels that are ones
      nVoxOnes=$(fslstats $TPmask -V | awk '{print $1}')
      nVox=$(fslstats $TPmask -v | awk '{print $1}')
      flgTooBig=$(echo $nVoxOnes $nVox | awk '{if($1>$2/10) print 1; else print 0}')
      # test if all values in the mask are either zeros or ones
      flgEmpty=$(fslstats $TPmask -R | awk '{if($1==$2) print 1; else print 0}')
      # if one of the two is true, make the mask empty
      if [[ $flgTooBig -eq 1 ]] || [[ $flgEmpty -eq 1 ]] ; then
        fslmaths $TPmask -mul 0 $TPmask
      fi
    done

  fi

  # combine brain mask with all the poles
  if [[ $flgFP == true ]] && [[ $flgTP == true ]] ; then
    fslmaths ${base}_brain_mask -add ${base}_Fpole_mask -add ${base}_TpoleL_mask -add ${base}_TpoleR_mask -bin ${base}_brain_mask
  elif [[ $flgFP == true ]] ; then
    fslmaths ${base}_brain_mask -add ${base}_Fpole_mask -bin ${base}_brain_mask
  elif [[ $flgTP == true ]] ; then
    fslmaths ${base}_brain_mask -add ${base}_TpoleL_mask -add ${base}_TpoleR_mask -bin ${base}_brain_mask
  fi

  # count the proportion of voxels that are ones
  nVoxOnes=$(fslstats ${base}_brain_mask -V | awk '{print $1}')
  nVox=$(fslstats ${base}_brain_mask -v | awk '{print $1}')
  flgTooBig=$(echo $nVoxOnes $nVox | awk '{if($1/$2>0.8) print 1; else print 0}')
  # test if all values in the mask are either zeros or ones
  flgEmpty=$(fslstats ${base}_brain_mask -R | awk '{if($1==$2) print 1; else print 0}')

  # check if the brain mask makes sense (actually has both zeros and ones)
  if [[ $flgTooBig -eq 1 ]] || [[ $flgEmpty -eq 1 ]] ; then
    >&2 echo "Error: I'm sorry, the brain mask is empty."
    >&2 echo "This is most likely an issue with the initial estimate of the brain size."
    >&2 echo "Run the command with '-d' (debug) to inspect the initial mask."
    >&2 echo "You could consider to change the initialisation parameters '-s'."
    if [[ $c -gt 0 ]] ; then
      >&2 echo "For now, the brain mask from the previous iteration is stored as the final result."
      imcp ${base}_brain_mask_previous ${base}_brain_mask
      exit 0
    else
      exit 1
    fi
  fi

  # test if the current brain mask is the same as the old
  if [[ $c -gt 0 ]] ; then
    # calculate the volume of the difference
    voldiff=$(fslstats ${base}_brain_mask -d ${base}_brain_mask_previous -a -V | awk '{print $2}')
    printf "      difference with previous iteration: %0.2f mm^3\n" $voldiff
    # compare to the tolerance
    if [[ $(echo $voldiff $tol | awk '($1<$2){print 1}') ]] ; then
      # iterations converged below tolerance
      echo "    iterations converged below tolerance (< ${tol} mm^3): stopping here."
      break
    fi
    # compare to the last difference
    if [[ $c -gt 1 ]] && [[ $(echo $voldiff $voldiff_previous | awk '($1>$2){print 1}') ]] ; then
      # the iteration start to diverge: take the previous iteration as the final result
      imcp ${base}_brain_mask_previous ${base}_brain_mask
      echo "    iterations started to diverge: taking the previous result as final."
      break
    fi
    # store the last difference
    voldiff_previous=$voldiff
  fi

  # store last brain mask, set size method to "bet", and increment counter
  imcp ${base}_brain_mask ${base}_brain_mask_previous
  size=bet
  ((++c))

  # store iteration mask
  [[ $flgdebug == TRUE ]] && imcp ${base}_brain_mask ${base}_brain_mask_${c}

done


# extract the brain
[[ $flgmaskonly != TRUE ]] && fslmaths $img -mas ${base}_brain_mask ${base}_brain

# clean up
if [[ $flgdebug != TRUE ]] ; then
  imrm ${base}_brain_ant_mask ${base}_brain_post_mask ${base}_Fpole ${base}_Fpole_mask ${base}_TpoleL_mask ${base}_TpoleR_mask ${base}_brain_mask_previous
fi

echo "    done"
