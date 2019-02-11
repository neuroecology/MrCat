#!/usr/bin/env bash
set -e    # stop immediately on error
umask u+rw,g+rw # give group read/write permissions to all new files

# This is an example resting state fMRI pipeline. It takes you from raw nifti_gz
# data to a preprocessed, registered dataset and dense connectome. The idea is
# that it is as modular as possible, so it's easy to add future steps
#
# Directory structure follows the HCP format a bit. There is a study directory,
# in there there are subject directories, in there directories according to the
# different spaces (functional, structural, F99, etc). In the functional data
# there should be a "raw.nii.gz", in the structural directory there should be a
# "struct.nii.gz"
#
# version history (a.k.a. the battle of the date notation conventions)
# 2018-05-01 Lennart completely revamped, massively expanded operations
# 2017-11-06 Lennart removed subject loop, added flexibility
# 2017-05-10 Lennart adapted
# 31052016 RBM  created

# TODO: the fsl_sub job names and waiting lists are out of date

# ------------------------------ #
# Defaults if no input is given (edit this part if you don't want to give input)
# ------------------------------ #

scriptDir=${MRCATDIR}/pipelines/rfmri_macaque
studyDir=/path/to/my/data
subj="monkey"
task="taskPlaceHolder"
flgFilter="hpbs"
maskNoise="WMcore_CSFcore"
nCompNoise=6
flgKeepSteps="FALSE" # FALSE or TRUE, keep all intermediate processing steps
flgSurfRes="low"

# ------------------------------ #
# Help (think twice before editing this part, or any below)
# ------------------------------ #

usage() {
cat <<EOF

rsn_pipeline.sh: run the resting-state fMRI pipeline

example:
    sh rsn_pipeline.sh --studydir=/you/are/here --subjdir=/path/to/monkey --reorient_func --preproc_func

usage: $(basename $0) --subjdir=A --taskA --taskB
    obligatory arguments
      --subjdir=X  : the subject directory to work in

    optional arguments
      --funcraw=X  : raw EPI timeseries, default: [subjdir]/functional/raw
      --funcproc=X : processed EPI timeseries, default: [subjdir]/functional/func
      --structimg=X: structural image, default: [subjdir]/structural/struct
      --logdir=X   : directory for the temporary and logfiles
      --filter=X   : 'lowpass', 'highpass', or 'bandpass' temporal filter using bptf
                     Alternatively, you can use a dedicated matlab function to
                     detect high-frequency noise components and bandstop filter,
                     supplemented with a bptf highpass filter. To implement this
                     option, select 'hpbs' (highpass-bandstop, default)
      --masknoise=X: mask defining the compartment from where noise components
                     are estimated in --cleancomp, default: WMcore_CSFcore
      --ncompnoise=X: number of noise components from the noise compartment mask
                     to use in --cleancomp, default: 6
      --keepsteps=X: TRUE or FALSE (default), to rename and keep the
                     intermediate steps
      --suffix=X   : the suffix that is appended after the basename, describing
                     the processing steps (see keepsteps). The default depends
                     on the current processing step and but assumes the
                     following task order: preproc_func > filter > cleancomp >
                     vol2surf > smooth > lowpasssurf > demean
      --surfres=X  : high or low (default) resolution of the surface (73k / 10k)
      --task       : the request task to run, from the list below

    task arguments
      The tasks are listed in the recommended order below. Please note that if
      you plan to use fsl_sub this order has been hard-coded in the job-naming
      and job-waiting instructions for fsl_sub for relevant tasks.
      --reorient_struct   : reorient the structural image (BSB convention)
      --preproc_struct    : preprocess the structural using 'struct_macaque.sh'
      --reorient_func     : reorient the functional image (BSB convention)
      TODO: these arguments should be updated
      --preproc_func      : bet and register the functional to the structural
                            using 'register_EPI_T1.sh'
      --filter            : apply a temporal filter to the volumetric data:
                            'highpass', 'lowpass',
                            'hpbs' (high-pass + band-stop, default),
                            'hpbslp' (high-pass + band-stop + low-pass),
                            'bslp' (band-stop + low-pass)
      --cleancomp         : regress out the noise components based on
                            --masknoise (common: WM/CSF compartments)
      --cleanvar[vol/surf]: variance normalisation of stochastic noise
                            --cleanvarvol works on volumetric data (.nii.gz)
                            --cleanvarsurf works on surface data (.dtseries.nii)
      --lowpass[vol/surf] : apply a low-pass temporal filter to clean data
                            --lowpassvol works on volumetric data (.nii.gz)
                            --lowpasssurf works on surface data (.dtseries.nii)
      --vol2surf          : project the functional data to the cortical surface
      --mask              : mask out the medial wall on the surface
      --smooth            : spatially smooth the data along the surface
      --demean            : demean the timeseries
      --normalize         : normalize (demean and standardize) the timeseries
      --cleanpca          : remove stochastic noise by principal component ana
      --cleanstochastic   : down-weight stochastic noise by weighted variance
                            normalisation and principal component analysis
      --dtseries2dconn    : cross-correlation to get a dense connectome

EOF
}


# ------------------------------ #
# Housekeeping
# ------------------------------ #

# if no arguments given, or help is requested, return the usage
if [[ $@ =~ --help ]] ; then usage; exit 0; fi
# if too few arguments given, return the usage, exit with error
if [[ $# -lt 1 ]] ; then echo ""; >&2 printf "\nError: not enough input arguments.\n\n"; usage; exit 1; fi

# parse the input arguments
#------------------------------
for a in "$@" ; do
  case $a in
    --subjdir=*)        subjDir="${a#*=}"; shift ;;
    --funcraw=*)        funcRaw="${a#*=}"; shift ;;
    --funcproc=*)       funcProc="${a#*=}"; shift ;;
    --suffix=*)         suffix="${a#*=}"; shift ;;
    --structimg=*)      structImg="${a#*=}"; shift ;;
    --logdir=*)         logDir="${a#*=}"; shift ;;
    --filter=*)         flgFilter="${a#*=}"; shift ;;
    --masknoise=*)      maskNoise="${a#*=}"; shift ;;
    --ncompnoise=*)     nCompNoise="${a#*=}"; shift ;;
    --keepsteps=*)      flgKeepSteps="${a#*=}"; shift ;;
    --surfres=*)        flgSurfRes="${a#*=}"; shift ;;
    --*)                taskList="$taskList ${a#--}"; shift ;;
    *)                  arg="$arg $a"; shift ;; # ordered arguments
  esac
done

# set default task if none specified
[[ -z $taskList ]] && taskList="$task"

# check if no redundant arguments have been set
if [[ -n $arg ]] ; then >&2 echo ""; >&2 echo "unsupported arguments are given: $arg"; usage; exit 1; fi

# ensure subjDir is an absolute path
subjDir="${subjDir/\~/$HOME}"
subjDir=$(cd $subjDir; pwd)

# infer or set the epi and structural images
[[ -z $funcRaw ]] && funcRaw=$subjDir/functional/raw
[[ -z $funcProc ]] && funcProc=$subjDir/functional/func
[[ -z $structImg ]] && structImg=$subjDir/structural/struct
funcRaw=$(remove_ext $funcRaw)
funcProc=$(remove_ext $funcProc)
funcDir=$(dirname $funcProc)
structImg=$(remove_ext $structImg)
structDir=$(dirname $structImg)

# set the intermediate file names
[[ -z $suffix ]] && suffix=""
if [[ $flgKeepSteps == "TRUE" ]] ; then
  sM="_mc"
  sB="_restore"
  sF="_$flgFilter"
  sC="_clean"
  sVv="_normstoch"
  sLv="_lp"
  sK=".masked"
  sS=".smooth"
  sLs=".lp"
  sN="X" # this will be filled in later depending on the type of normalization
  sVs=".normstoch"
  sP=".pca"
else
  sM="_mc" # dissociate between original and motion-corrected data
  sB=""
  sF="_$flgFilter" # always keep the filter name
  sC="_clean" # always save a copy of the data before noise regression
  sVv=""
  sLv="_lp"
  sK=""
  sS=".smooth"
  sLs=""
  sN=""
  sVs=""
  sP=".pca"
fi

# set the default noise mask and suffix for the cleaning step
if [[ -n $sC ]] ; then
  [[ $maskNoise =~ ero ]] && [[ ! $maskNoise =~ core ]] && sC+="Ero"
  [[ $maskNoise =~ WM ]] && sC+="WM"
  [[ $maskNoise =~ CSF ]] && sC+="CSF"
fi

# set resolution of the surface
if [[ $flgSurfres == "high" ]] ; then
  surfName="F99_74k"
  surfLeft=$MRCATDIR/data/macaque/F99/surf/left.fiducial.F99.surf.gii
  surfRight=$MRCATDIR/data/macaque/F99/surf/right.fiducial.F99.surf.gii
else
  surfName="F99_10k"
  surfLeft=$MRCATDIR/data/macaque/F99/surf/left.fiducial.F99_10k.surf.gii
  surfRight=$MRCATDIR/data/macaque/F99/surf/right.fiducial.F99_10k.surf.gii
fi

# esure MrCat is set up
if [[ $SETUPMRCAT != "TRUE" ]] ; then if [[ -n $MRCATDIR ]] ; then source $MRCATDIR/setupMrCat.sh ; else >&2 echo ""; >&2 echo "please source \"setupMrCat.sh\" before running this script"; exit 1; fi; fi

# ensure the wb_command binary directory is set
[[ -z $WBBIN ]] && WBBIN=$(dirname "$(which wb_command)")

# run local, or setup the fsl_sub requirements
if [[ $RUN =~ ^fsl_sub ]] ; then
  [[ -z $logDir ]] && logDir=$(cd $subjDir/..; pwd)/log
  mkdir -p $logDir
  flgMemLimit="-mem-limit 6"
  flgMemQueue="short.q"
else
  RUN=""
  flgMemLimit=""
  flgMemQueue=""
fi


#=======================================
# Do the work
#=======================================

# loop over tasks
for task in $taskList ; do

  # switch depending on task
  case $task in

    #---------------------------------------
    # reorient structural image
    #---------------------------------------
    reorient_struct )
      printf "\n  Task: reorienting structural image\n"
      [[ $RUN =~ ^fsl_sub ]] && RUN="fsl_sub -q veryshort.q -N reorient_struct -l $logDir"
      $RUN sh $scriptDir/rsn_reorient.sh $structImg --method=orient
      ;;


    #---------------------------------------
    # preprocess structural image
    #---------------------------------------
    preproc_struct )
      printf "\n  Task: brain extraction and registration of the structural data\n"
      [[ $RUN =~ ^fsl_sub ]] && RUN="fsl_sub -q long.q -N preproc_struct -j reorient_struct -l $logDir"
      $RUN sh $MRCATDIR/core/struct_macaque.sh --subjdir=$subjDir --structimg=$structImg --all --refspace=F99 --refimg=${MRCATDIR}/data/macaque/F99/McLaren
      mkdir -p $subjDir/log
      [[ $RUN =~ ^fsl_sub ]] && RUN="fsl_sub -q veryshort.q -N slices -j preproc_struct -l $logDir"
      $RUN slices $structImg ${structImg}_brain_mask -o $subjDir/log/struct_bet.gif
    ;;


    #---------------------------------------
    # segment structural data (already done if you ran preproc_struct with --all)
    #---------------------------------------
    segment )
      printf "\n  Task: segmenting structural image\n"
      [[ $RUN =~ ^fsl_sub ]] && RUN="fsl_sub -q veryshort.q -N segment -j preproc_struct -l $logDir"
      $RUN sh $MRCATDIR/core/struct_macaque.sh --subjdir=$subjDir --structimg=$structImg --segment --refspace=F99 --refimg=${MRCATDIR}/data/macaque/F99/McLaren
    ;;


    #---------------------------------------
    # create hemisphere masks (already done if you ran preproc_struct with --all)
    #---------------------------------------
    hemimask )
      printf "\n  Task: creating hemisphere masks\n"
      [[ $RUN =~ ^fsl_sub ]] && RUN="fsl_sub -q veryshort.q -N hemimask -j preproc_struct -l $logDir"
      #$RUN sh $MRCATDIR/core/struct_macaque.sh --subjdir=$subjDir --structimg=$structImg --hemimask --refspace=F99 --refimg=${MRCATDIR}/data/macaque/F99/McLaren
      sh $MRCATDIR/core/struct_macaque.sh --subjdir=$subjDir --structimg=$structImg --hemimask --refspace=F99 --refimg=${MRCATDIR}/data/macaque/F99/McLaren
    ;;


    #---------------------------------------
    # reorient functional data
    #---------------------------------------
    # when orientation information is not present or wrong, but data is the right way up
    reorient_func )
      printf "\n  Task: reorienting functional data (data is right way up, but orientation labels are wrong)\n"
      [[ $RUN =~ ^fsl_sub ]] && RUN="fsl_sub -q veryshort.q -N reorient_func -l $logDir"
      $RUN sh $scriptDir/rsn_reorient.sh $funcRaw --method=orient
    ;;

    # when correct orientation information is present, but data is not the right way up
    reorient2std_func )
      printf "\n  Task: reorienting functional data (orientation labels are correct, but data is not the right way up)\n"
      [[ $RUN =~ ^fsl_sub ]] && RUN="fsl_sub -q veryshort.q -N reorient_func -l $logDir"
      $RUN sh $scriptDir/rsn_reorient.sh $funcRaw --method=standard
    ;;

    # when correct orientation information is present, but data is not the right way up
    swapdim_func )
      printf "\n  Task: reorienting functional data (data is not the right way up, and orientation labels are wrong, no R-L guarantee!)\n"
      [[ $RUN =~ ^fsl_sub ]] && RUN="fsl_sub -q veryshort.q -N swapdim_func -l $logDir"
      $RUN sh $scriptDir/rsn_reorient.sh $funcRaw --method=swapdim
      #$RUN sh $scriptDir/rsn_swapdim.sh $funcRaw -x z y
    ;;


    #---------------------------------------
    # cut first n volumes from functional data
    #---------------------------------------
    # cut out the first n seconds (default: 10) until a steady state of radio-frequency excitation
    discardfirstvols )
      printf "\n  Task: discarding first volumes until steady RF excitation state\n"
      [[ $RUN =~ ^fsl_sub ]] && RUN="fsl_sub -q veryshort.q -N discardfirst -l $logDir"
      $RUN sh $scriptDir/rsn_discardFirstVols.sh $funcRaw --seconds=10
    ;;


    #---------------------------------------
    # motion correction
    #---------------------------------------
    # cut out sections with big jumps in image contents (artefacts/movements)
    motioncorr )
      printf "\n  Task: robust motion correction\n"
      [[ $RUN =~ ^fsl_sub ]] && RUN="fsl_sub -q veryshort.q -N cutjumps -l $logDir"
      $RUN sh $scriptDir/rsn_motionCorr.sh $funcRaw ${funcRaw}${sM}
    ;;


    #---------------------------------------
    # fix and cut outliers
    #---------------------------------------
    # fix and cut outliers caused by artefacts and/or movements
    outlier* )
      printf "\n  Task: fixing and cutting outliers\n"
      # read in dataset specific instructions, if they exist
      instructOutlierFile=$funcDir/instructOutlier.txt
      [[ -f $instructOutlierFile ]] && instructOutlier=$(cat $instructOutlierFile) || instructOutlier=""
      # prepare the command
      [[ $RUN =~ ^fsl_sub ]] && RUN="fsl_sub -q veryshort.q -N outlier -l $logDir"
      case $task in
        outlier ) instructOutlier+=" --cutother=${funcRaw}${sM}.par" ;;
        outlierdetect ) instructOutlier+=" --detect" ;;
        outliercut ) instructOutlier+=" --cut --cutother=${funcRaw}${sM}.par" ;;
        * ) printf "\n    unsupported outlier task: %s\n    please select from 'outlier', 'outlierdetect', or 'outliercut'\n\n" $task ; exit 1 ;;
      esac
      $RUN sh $scriptDir/rsn_outlier.sh ${funcRaw}${sM} --ref=${funcRaw}_ref $instructOutlier
    ;;


    #---------------------------------------
    # register functional to structural
    #---------------------------------------
    # register functional to structural
    register )
      printf "\n  Task: register functional to structural\n"
      [[ $RUN =~ ^fsl_sub ]] && RUN="fsl_sub -q veryshort.q -N register -l $logDir"
      $RUN sh $scriptDir/rsn_registerFunc2Struct.sh ${funcRaw}${sM} ${structImg}_restore $funcProc
    ;;


    #---------------------------------------
    # bias correction
    #---------------------------------------
    # RF inhomogeniety / intensity bias correction
    biascorr )
      printf "\n  Task: intensity bias correction\n"
      # set the new suffix for the functional data
      if [[ -n $suffix ]] ; then
        if [[ -n $sB ]] ; then
          >&2 printf "Warning! The user specified suffix (%s) will be overwritten with %s\n\n" $suffix $sB
        else
          >&2 printf "Warning! The user specified suffix (%s) will be ignored for the functional data\n\n" $suffix
        fi
      fi
      suffix=${sB}
      # run the bias correction
      [[ $RUN =~ ^fsl_sub ]] && RUN="fsl_sub -q veryshort.q -N biascorr -l $logDir"
      $RUN sh $scriptDir/rsn_biascorr.sh $funcProc ${funcProc}${suffix} --rawmean=${funcRaw}${sM}_mean
    ;;


    #---------------------------------------
    # Filter functional data
    #---------------------------------------
    filter )
      printf "\n  Task: filtering functional data\n"
      [[ $RUN =~ ^fsl_sub ]] && RUN="fsl_sub -q short.q -N filter -j preproc_func -l $logDir"
      [[ -z $suffix ]] && suffix=${sB}
      suffixOut=${suffix}${sF}

      # default high-pass and low-pass cutoff in seconds
      # whether these are applied depends on the setting in $flgFilter
      highpass=2000
      lowpass=10

      # extract TR
      TR=$(fslval $funcProc "pixdim4")

      # run the filter (either in matlab or using fslmaths)
      if [[ $flgFilter =~ bs ]] ; then
        # run a band-stop filter in matlab to remove isolated noise peaks

        # setup matlab input arguments
        # TODO: add a matlab crash error etc
        fnameIn="${funcProc}${suffix}.nii.gz"
        fnameOut="${funcProc}${suffixOut}.nii.gz"
        fnameMask="${funcProc}_brain_mask.nii.gz"
        nComp=3
        # setup additional high-pass and low-pass filters
        [[ ! $flgFilter =~ hp ]] && highpass="-1"
        [[ ! $flgFilter =~ lp ]] && lowpass="-1"

        # call matlab
        $RUN $MATLABBIN/matlab -nodisplay -nosplash -r "addpath('$MRCATDIR');setupMrCat;rsn_filter('$fnameIn','$fnameOut','$fnameMask',$TR,$nComp,[1/$highpass 1/$lowpass],'fsl','but','$flgFilter','',false);exit"
      else

        # convert filter frequencies from seconds to TR-sigmas
        lowpassTR=$(echo "10 k $lowpass 2 / $TR / p" | dc -)
        highpassTR=$(echo "10 k $highpass 2 / $TR / p" | dc -)
        # use low- and/or highpass
        [[ $flgFilter == "lowpass" ]] && highpassTR="-1"
        [[ $flgFilter == "highpass" ]] && lowpassTR="-1"

        # call fslmaths
        $RUN fslmaths ${funcProc}${suffix} -bptf $highpassTR $lowpassTR ${funcProc}${suffixOut}

      fi
      suffix=$suffixOut
    ;;


    #---------------------------------------
    # Clean: regress out noise compartment signals (WM/CSF)
    #---------------------------------------
    cleancomp )
      [[ $maskNoise =~ WM ]] && strMaskNoise=" (WM)"
      [[ $maskNoise =~ CSF ]] && strMaskNoise=" (CSF)"
      [[ $maskNoise =~ WM ]] && [[ $maskNoise =~ CSF ]] && strMaskNoise=" (WM/CSF)"
      printf "\n  Task: cleaning by regressing noise%s components\n" $strMasknoise
      [[ $RUN =~ ^fsl_sub ]] && RUN="fsl_sub -q short.q -N cleancomp -j filter -l $logDir"
      [[ -z $suffix ]] && suffix=${sB}${sF}
      suffixOut=${suffix}${sC}

      $RUN sh $scriptDir/rsn_cleanComp.sh \
        --funcimg=${funcProc}${suffix} \
        --funcout=${funcProc}${suffixOut} \
        --funcbase="$(basename $funcProc)" \
        --transdir=$subjDir/transform \
        --structimg=$structImg \
        --motion=${funcRaw}${sM}.par \
        --motiondegree=2 \
        --decomp="pca" \
        --masknoise="$maskNoise" --ncomp=$nCompNoise

        # below are the default options for PCA cleaning
        #--decomp="pca" \
        #--masknoise="$maskNoise" --ncomp=6

        # below are a the default options for ICA cleaning
        #--decomp="ica" \
        #--masknoise="$maskNoise" --ncomp=12 \
        #--masksignal="GM" --ncompsignal=24
      suffix=$suffixOut
    ;;


    #---------------------------------------
    # weighted variance normalization of unstructured noise
    #---------------------------------------
    cleanvar* )
      printf "\n  Task: Variance normalisation of stochastic noise\n"
      if [[ $task =~ vol$ ]] ; then
        [[ -z $suffix ]] && suffix=${sB}${sF}${sC}
        suffixOut=${suffix}${sVv}
        fnameIn="${funcProc}${suffix}.nii.gz"
        fnameOut="${funcProc}${suffixOut}.nii.gz"
        [[ $RUN =~ ^fsl_sub ]] && RUN="fsl_sub -q veryshort.q -N normstoch -j cleancomp -l $logDir"
      else
        [[ -z $suffix ]] && suffix=${sB}${sF}${sC}${sLv}${sK}${sS}
        suffixOut=${suffix}${sVs}
        fnameIn="${funcProc}${suffix}.$surfName.dtseries.nii"
        fnameOut="${funcProc}${suffixOut}.$surfName.dtseries.nii"
        [[ $RUN =~ ^fsl_sub ]] && RUN="fsl_sub -q veryshort.q -N normstoch -j smooth -l $logDir"
      fi
      # TODO: add a matlab crash error etc
      $RUN $MATLABBIN/matlab -nodisplay -nosplash -r "addpath('$MRCATDIR');setupMrCat;rsn_cleanVariance('$fnameIn','$fnameOut','${WBBIN}/wb_command');exit"
      suffix=$suffixOut
    ;;


    #---------------------------------------
    # low-pass filter functional data in time-domain
    #---------------------------------------
    lowpass* )
      printf "\n  Task: temporal low-pass filtering\n"

      # low-pass cutoff in seconds
      lowpass=10

      # extract TR
      TR=$(fslval $funcProc "pixdim4")

      # switch depending on data type
      if [[ $task =~ vol$ ]] ; then
        # volumetric processing
        [[ -z $suffix ]] && suffix=${sB}${sF}${sC}
        suffixOut=${suffix}${sLv}

        # low-pass cutoff in TR
        lowpassTR=$(echo "10 k $lowpass 2 / $TR / p" | dc -)
        # run the filter using fslmaths
        [[ $RUN =~ ^fsl_sub ]] && RUN="fsl_sub -q short.q -N filter -j preproc_func -l $logDir"
        $RUN fslmaths ${funcProc}${suffix} -bptf -1 $lowpassTR ${funcProc}${suffixOut}

      else
        # surface processing
        [[ -z $suffix ]] && suffix=${sB}${sF}${sC}${sK}${sS}
        suffixOut=${suffix}${sLs}

        # setup matlab input arguments
        # TODO: add a matlab crash error etc
        fnameIn="${funcProc}${suffix}.$surfName.dtseries.nii"
        fnameOut="${funcProc}${suffixOut}.$surfName.dtseries.nii"

        # call matlab
        $RUN $MATLABBIN/matlab -nodisplay -nosplash -r "addpath('$MRCATDIR');setupMrCat;rsn_filter('$fnameIn','$fnameOut','',$TR,0,[-1 1/$lowpass],'but','but','lp','${WBBIN}/wb_command',false);exit"

      fi


      suffix=$suffixOut
    ;;


    #---------------------------------------
    # Project functional data to F99 surface to create dtseries
    #---------------------------------------
    vol2surf )
      printf "\n  Task: projecting functional volumetric data to cortical surface \n"
      [[ -z $suffix ]] && suffix=${sB}${sF}${sC}
      [[ $RUN =~ ^fsl_sub ]] && RUN="fsl_sub -q veryshort.q -N vol2surf -j filter,cleancomp -l $logDir"

      $RUN sh $scriptDir/rsn_vol2surf.sh \
        --funcimg=${funcProc}${suffix} \
        --funcbase="$(basename $funcProc)" \
        --structimg=$structImg \
        --projmethod=myelin \
        --surfname=$surfName --surfleft=$surfLeft --surfright=$surfRight
    ;;


    #---------------------------------------
    # Mask out the medial wall
    #---------------------------------------
    mask )
      printf "\n  Task: Masking the medial wall\n"
      [[ -z $suffix ]] && suffix=${sB}${sF}${sC}${sLv}
      suffixOut=${suffix}${sK}

      # set data on the medial wall to zeros
      [[ $RUN =~ ^fsl_sub ]] && RUN="fsl_sub -q veryshort.q -N mask -j cleancomp,lowpassvox -l $logDir"
      $RUN wb_command -cifti-math "(data*mask)" ${funcProc}${suffixOut}.$surfName.tmp.dtseries.nii \
        -var "data" ${funcProc}${suffix}.$surfName.dtseries.nii \
        -var "mask" $MRCATDIR/data/macaque/F99/surf/cortex_subcort.roi.F99_10k.dscalar.nii -select 1 1 -repeat > /dev/null

      # clean up (different file name was used to avoid computing output in memory)
      mv -f ${funcProc}${suffixOut}.$surfName.tmp.dtseries.nii ${funcProc}${suffixOut}.$surfName.dtseries.nii
      suffix=$suffixOut
    ;;


    #---------------------------------------
    # Smooth dtseries along the cortical surface
    #---------------------------------------
    smooth )
      printf "\n  Task: Smoothing the dtseries\n"
      [[ -z $suffix ]] && suffix=${sB}${sF}${sC}${sLv}${sK}
      suffixOut=${suffix}${sS}

      [[ $RUN =~ ^fsl_sub ]] && RUN="fsl_sub -q veryshort.q -N smooth -j demean,normalize -l $logDir"
      $RUN $WBBIN/wb_command -cifti-smoothing \
  		  ${funcProc}${suffix}.$surfName.dtseries.nii \
  		  3 4 COLUMN \
  		  ${funcProc}${suffixOut}.$surfName.dtseries.nii \
  		  -left-surface $surfLeft \
        -right-surface $surfRight \
        -fix-zeros-volume \
        -fix-zeros-surface
      suffix=$suffixOut
    ;;


    #---------------------------------------
    # demean time courses
    #---------------------------------------
    demean )
      printf "\n  Task: Demeaning time courses\n"
      # set a bespoke suffix
      if [[ -n $sN ]] ; then [[ $sN == "X" ]] && sN=".demean" || sN+=".demean"; fi
      [[ -z $suffix ]] && suffix=${sB}${sF}${sC}${sLv}${sK}${sS}
      suffixOut=${suffix}${sN}

      # create a temporary shell script to execute a list of commands
      fname="${funcProc}${suffix}.$surfName.dtseries.nii"
      tmpFile=$(mktemp "$funcDir/tmp.XXXXXXXXXX")
      cat > $tmpFile <<EOF
      ${WBBIN}/wb_command -cifti-reduce $fname MEAN ${tmpFile}.mean.dscalar.nii
      ${WBBIN}/wb_command -cifti-math "(data-mean)" ${funcProc}${suffixOut}.$surfName.dtseries.nii -var "data" $fname -var "mean" ${tmpFile}.mean.dscalar.nii -select 1 1 -repeat > /dev/null
      rm -f ${tmpFile}.mean.dscalar.nii
      rm ${tmpFile}
EOF
      [[ $RUN =~ ^fsl_sub ]] && RUN="fsl_sub -q veryshort.q -N demean -j vol2surf -l $logDir"
      #$RUN $MATLABBIN/matlab -nodisplay -nosplash -r "addpath('$MRCATDIR');setupMrCat;rsn_demean('$fname','$sN');exit"
      $RUN sh $tmpFile
      suffix=$suffixOut
    ;;


    #---------------------------------------
    # Normalize time courses
    #---------------------------------------
    normalize )
      printf "\n  Task: Normalizing time courses\n"
      # set a bespoke suffix
      if [[ -n $sN ]] ; then [[ $sN == "X" ]] && sN=".norm" || sN+=".norm"; fi
      [[ -z $suffix ]] && suffix=${sB}${sF}${sC}${sLv}${sK}${sS}
      suffixOut=${suffix}${sN}
      # TODO: add a matlab crash error etc
      fname="${funcProc}${suffix}.$surfName.dtseries.nii"
      [[ $RUN =~ ^fsl_sub ]] && RUN="fsl_sub -q veryshort.q -N normalize -j vol2surf -l $logDir"
      $RUN $MATLABBIN/matlab -nodisplay -nosplash -r "addpath('$MRCATDIR');setupMrCat;rsn_normalise('$fname','$sN');exit"
      suffix=$suffixOut
    ;;


    #---------------------------------------
    # Clean: weighted variance normalization and PCA
    #---------------------------------------
    cleanstochastic )
      printf "\n  Task: down-weight stochastic noise (variance normalization and PCA)\n"
      [[ -z $suffix ]] && suffix=${sB}${sF}${sC}${sLv}${sK}${sS}
      suffixOut=${suffix}${sP}
      # TODO: add a matlab crash error etc
      fnameIn="${funcProc}${suffix}.$surfName.dtseries.nii"
      fnameOut="${funcProc}${suffixOut}.$surfName.dtseries.nii"
      [[ $RUN =~ ^fsl_sub ]] && RUN="fsl_sub -q veryshort.q -N varnormpca -j smooth -l $logDir"
      $RUN $MATLABBIN/matlab -nodisplay -nosplash -r "addpath('$MRCATDIR');setupMrCat;rsn_cleanVariancePca('$fnameIn',600,400,'$fnameOut','${WBBIN}/wb_command');exit"
      suffix=$suffixOut
    ;;


    #---------------------------------------
    # Clean: PCA to ignore stochastic components
    #---------------------------------------
    cleanpca )
      printf "\n  Task: removing unstructured principal components\n"
      [[ -z $suffix ]] && suffix=${sB}${sF}${sC}${sLv}${sK}${sS}
      suffixOut=${suffix}${sP}
      # TODO: add a matlab crash error etc
      fnameIn="${funcProc}${suffix}.$surfName.dtseries.nii"
      fnameOut="${funcProc}${suffixOut}.$surfName.dtseries.nii"
      [[ $RUN =~ ^fsl_sub ]] && RUN="fsl_sub -q veryshort.q -N cleanpca -j smooth -l $logDir"
      $RUN $MATLABBIN/matlab -nodisplay -nosplash -r "addpath('$MRCATDIR');setupMrCat;rsn_cleanPca('$fnameIn',250,200,'$fnameOut','${WBBIN}/wb_command');exit"
      suffix=$suffixOut
    ;;


    #---------------------------------------
    # unsupported task
    #---------------------------------------
    *)
      printf "\n  Task: Unsupported task requested (%s)\n" $task
    ;;

  esac
done


#---------------------------------------
# Round-up
#---------------------------------------


# report
if [[ $RUN =~ ^fsl_sub ]] ; then
  printf "\nAll jobs submitted!\n\n"
else
  printf "\nDone!\n\n"
fi
