#!/usr/bin/env bash
umask u+rw,g+rw # give group read/write permissions to all new files
set -e    # stop immediately on error

<<"COMMENT"

project: deepTUS
first: Lennart Verhagen, Davide Folloni
last: Matthew Rushworth, Jerome Sallet
code: Lennart Verhagen

goal:
create a heatmap of TUS induced changes to connectivity

prepare:
1. calculate dconns
2. calculate 75% scaling factor

steps:
1. write new ROI instructions
2. create the ROIs
3. copy original instructions back

4. write SBCA instructions and configurations
5. extract the sbca data from the ROIs
6. copy original instructions and configurations back

7. extract 90% scaling factor of overall connectivity
8. normalise fingerprints by scaling factor

9. compare control with TUS-amyg and TUS-ACC

10. calculate the cosine metric in matlab (ConnHeatmapCosineSimilarity.m)

todo:
remove TODOs and HACKs

COMMENT

#----------#
# OVERHEAD #
#----------#

# DEBUG: set what part to run
flgDebug=1
flgRunCreateROI=0
flgRunSeedConn=0
flgRunNormalise=0
flgRunCompareConn=1

# DEBUG: use normalised data or not
suffixNorm=".normalised"
#suffixNorm=""

# definitions
source $MRCATDIR/setupMrCat.sh
studyDir="/Volumes/rsfMRI/anaesthesia"
anaDir="$studyDir/analysis"
mkdir -p $anaDir/map

# create a temporary directory to store intermediate results
if [[ $flgDebug -eq 1 ]] ; then
  # DEBUG
  tmpDir=$anaDir/tmp.ConnHeatmap.ldviIs7M3r
else
  tmpDir=$(mktemp -d "$anaDir/tmp.ConnHeatmap.XXXXXXXXXX")
fi


#--------------#
# CREATE ROIS #
#--------------#
# check $MRCATDIR/projects/fun/CreateROI.sh for more details
if [[ $flgRunCreateROI -eq 1 ]] ; then

  # write new instructions to create ROIs
  cat > $tmpDir/instructCreateRoi_heatmap.txt <<EOF
Ts2
pIPS
M1med
24ab
8m
9mc
46
9-46v
11m
14
11
13
47-12o
strm
EOF

  # define the ROI instruction file
  instructFile=$anaDir/instruct/instructCreateRoi.txt

  # make a back-up of the original instructions
  [[ -s $instructFile ]] && mv $instructFile $tmpDir/instructCreateRoi_backup.txt

  # copy the new instructions to the instruction folder
  cp $tmpDir/instructCreateRoi_heatmap.txt $instructFile

  # ensure this is a valid instruction file
  [[ ! -s $instructFile ]] && echo "" && >&2 printf "\nError: no valid instruction file found at:\n%s\n\n" $instructFile && exit 1
  [[ $(tail -c1 $instructFile | wc -l) -le 0 ]] && echo "" >> $instructFile

  # create the ROIs
  sh $MRCATDIR/projects/fun/CreateROI.sh

  # restore original instructions
  [[ -s $tmpDir/instructCreateRoi_backup.txt ]] && mv $tmpDir/instructCreateRoi_backup.txt $instructFile || rm -f $instructFile

fi


#------#
# SBCA #
#------#
# check $MRCATDIR/projects/fun/SeedConn.sh for more details
if [[ $flgRunSeedConn -eq 1 ]] ; then

  # write new instructions to do the seed-based connectivity analysis
  cat > $tmpDir/sourceConfig_heatmap.sh <<EOF
#!/usr/bin/env bash
umask u+rw,g+rw # give group read/write permissions to all new files
set -e    # stop immediately on error

# specify the study and dataset origin
flgStudy="deepTUS" #fmriTUS, deepTUS
flgCity="Oxford" # Oxford, Paris

# specify the dataset version (denoted with a suffix), based on the study
suffixClean="EroWMCSF" # deepTUS study: "EroWMCSF", "CoreWMCSF"

# specify to work on the group- or a run-specific dataset
suffixAnaLevelList="group"

# specify the datatype
flgDataType="data"

# specify to cap the Fisher's z-stats
flgCapStat=1

# specify whether this is a validation analysis
flgValidate=0

# specify the fingerprint summary statistic
flgSummaryStat="MEAN"

# specify data based on flag settings (above)
suffixTS="_hpbs_clean${suffixClean}_lp.smooth"
suffixConn=".clean${suffixClean}"

# adjust the suffix based on the flags
[[ $flgValidate -eq 1 ]] && suffixValidate=".validation" || suffixValidate=""
[[ $flgValidate -eq 1 ]] && suffixConn+=$suffixValidate
[[ $flgCapStat -eq 0 ]] && suffixConn+=".noCap"

# specify the analysis level: SUBJRUN, SESSRUN, RUN, SESS, SUBJ, GROUP, or any combination (RUN_SUBJ_GROUP)
flgLevel="GROUP"

# specify which runs to consider for the RUN level analysis
runList="run1 run2 run3"

# specify the surface version
surf="F99_10k"
EOF

  # define configuration file
  configFile=$anaDir/instruct/sourceConfig.sh

  # make a back-up of the original configuration file
  [[ -s $configFile ]] && mv $configFile $tmpDir/sourceConfig_backup.sh

  # copy the new configuration to the configuration folder
  cp $tmpDir/sourceConfig_heatmap.sh $configFile

  # write new instructions to do the seed-based connectivity analysis
  cat > $tmpDir/instructSeedConn_heatmap.txt <<EOF
control9 Ts2 pIPS M1med 24ab 8m 9mc 46 9-46v 11m 14 11 13 47-12o strm
pgacc Ts2 pIPS M1med 24ab 8m 9mc 46 9-46v 11m 14 11 13 47-12o strm
amyg Ts2 pIPS M1med 24ab 8m 9mc 46 9-46v 11m 14 11 13 47-12o strm
EOF

  # define the ROI instruction file
  instructFile=$anaDir/instruct/instructSeedConn.txt

  # make a back-up of the original instructions
  [[ -s $instructFile ]] && mv $instructFile $tmpDir/instructSeedConn_backup.txt

  # copy the new instructions to the instruction folder
  cp $tmpDir/instructSeedConn_heatmap.txt $instructFile

  # ensure this is a valid instruction file
  [[ ! -s $instructFile ]] && echo "" && >&2 printf "\nError: no valid instruction file found at:\n%s\n\n" $instructFile && exit 1
  [[ $(tail -c1 $instructFile | wc -l) -le 0 ]] && echo "" >> $instructFile

  # abort if a back-up sbca folder has been found
  [[ -d $anaDir/sbca_backup ]] && echo "" && >&2 printf "\nError: back-up sbca folder detected, aborting for safety.\nPlease sort out the sbca (backup) folder(s) manually.:\n%s\n\n" $anaDir/sbca_backup && exit 1

  # back-up the original sbca folder
  [[ -d $anaDir/sbca ]] && mv $anaDir/sbca $anaDir/sbca_backup

  # create a new sbca folder
  mkdir -p $anaDir/sbca

  # run the seed-based correlation analysis
  sh $MRCATDIR/projects/fun/SeedConn.sh

  # move the new sbca folder to the temporary directory and put the back_up back
  mv $anaDir/sbca $tmpDir/sbca
  [[ -d $anaDir/sbca_backup ]] && mv $anaDir/sbca_backup $anaDir/sbca

  # restore original configurations
  [[ -s $tmpDir/sourceConfig_backup.sh ]] && mv $tmpDir/sourceConfig_backup.sh $configFile || rm -f $configFile

  # restore original instructions
  [[ -s $tmpDir/instructSeedConn_backup.txt ]] && mv $tmpDir/instructSeedConn_backup.txt $instructFile || rm -f $instructFile

fi


#-----------#
# NORMALISE #
#-----------#
if [[ $flgRunNormalise -eq 1 ]] ; then

  # start a timer
  SECONDS=0
  echo ""
  echo "NORMALISING CONNECTIONAL FINGERPRINTS"

  # write instructions compare the connectional fingerprints
  instructFile=$tmpDir/instructNormaliseConn_heatmap.txt
  cat > $instructFile <<EOF
control9
amyg
pgacc
EOF

  # try to retrieve the dataset suffices, or opt for defaults
  [[ -f $tmpDir/sourceConfig_heatmap.sh ]] && source $tmpDir/sourceConfig_heatmap.sh
  [[ -z $suffixClean ]] && suffixClean="EroWMCSF"
  [[ -z $suffixConn ]] && suffixConn=".clean${suffixClean}"

  # loop over FUN sites
  while read -r siteName ; do
    echo "  $siteName"

    # define connectivity data
    seedConn=$tmpDir/sbca/group/${siteName}${suffixConn}.sbca.dscalar.nii

    # convert to text file
    wb_command -cifti-convert -to-text $seedConn $tmpDir/${siteName}.txt

    # loop over columns
    nCol=$(awk '{print NF; exit}' $tmpDir/${siteName}.txt)
    for col in $(seq 1 $nCol) ; do

      # calculate the scaling factor (90-percentile of positive coupling)
      scaleFact=$(cut -f$col $tmpDir/${siteName}.txt | sort -g | awk 'BEGIN{c=0} ($0>0){a[c]=$0;c++}END{print a[int(c*0.9 - 0.5)]}')

      # scale data
      if [[ $col -eq 1 ]] ; then
        awk '{print $"'"$col"'"/"'"$scaleFact"'"}' $tmpDir/${siteName}.txt > $tmpDir/${siteName}.normalised.txt
      else
        awk '{print $"'"$col"'"/"'"$scaleFact"'"}' $tmpDir/${siteName}.txt | paste $tmpDir/${siteName}.normalised.txt - > $tmpDir/${siteName}.normalisedTmp.txt
        mv $tmpDir/${siteName}.normalisedTmp.txt $tmpDir/${siteName}.normalised.txt
      fi

    done

    # convert back to cifti
    wb_command -cifti-convert -from-text $tmpDir/${siteName}.normalised.txt $seedConn $tmpDir/sbca/group/${siteName}${suffixConn}.sbca.normalised.dscalar.nii

    # clean up
    rm $tmpDir/${siteName}.txt $tmpDir/${siteName}.normalised.txt

  done < $instructFile

  echo ""
  echo "DONE"
  echo "  seconds elapsed: $SECONDS"
  echo ""

fi


#------------#
# COMPARISON #
#------------#
if [[ $flgRunCompareConn -eq 1 ]] ; then

  # start a timer
  SECONDS=0
  echo ""
  echo "COMPARING CONNECTIONAL FINGERPRINTS"

  # write instructions compare the connectional fingerprints
  instructFile=$tmpDir/instructCompareConn_heatmap.txt
  cat > $instructFile <<EOF
control9 amyg
control9 pgacc
EOF

  # try to retrieve the dataset suffices, or opt for defaults
  [[ -f $tmpDir/sourceConfig_heatmap.sh ]] && source $tmpDir/sourceConfig_heatmap.sh
  [[ -z $suffixClean ]] && suffixClean="EroWMCSF"
  [[ -z $suffixConn ]] && suffixConn=".clean${suffixClean}"

  # ensure the map directory exists
  mkdir -p $tmpDir/map

  # loop over FUN sites
  while read -r siteNameA siteNameB ; do
    echo ""
    echo "  comparing coupling from \"$siteNameA\" with \"$siteNameB\""

    # specify the datasets
    connAall=$tmpDir/sbca/group/${siteNameA}${suffixConn}.sbca${suffixNorm}.dscalar.nii
    connBall=$tmpDir/sbca/group/${siteNameB}${suffixConn}.sbca${suffixNorm}.dscalar.nii

    # loop over hemispheres
    for hemi in all bilat left right ; do

      # specify output file
      prefixOut=$tmpDir/map/${siteNameA}.${siteNameB}${suffixConn}.${hemi}

      if [[ $hemi == "all" ]] ; then
        # nothing to do here
        connA=$connAall
        connB=$connBall

      else

        # new file names for the hemisphere specific datasets
        connA=$tmpDir/sbca/group/${siteNameA}${suffixConn}.sbca${suffixNorm}.${hemi}.dscalar.nii
        connB=$tmpDir/sbca/group/${siteNameB}${suffixConn}.sbca${suffixNorm}.${hemi}.dscalar.nii

        # extract the list of bilateral map names
        strCol=$(wb_command -file-information $connAall -only-map-names | grep -n ".$hemi" | cut -d':' -f1)
        strCol=$(printf ' -column %s ' $strCol)

        # extract selected maps from the whole set
        wb_command -cifti-merge $connA -cifti $connAall $strCol
        wb_command -cifti-merge $connB -cifti $connBall $strCol

      fi

      # difference
      wb_command -cifti-math "(A-B)" $prefixOut.diff.dscalar.nii -fixnan 0 -var "A" $connA -var "B" $connB > /dev/null
      wb_command -cifti-reduce $prefixOut.diff.dscalar.nii MEAN $prefixOut.diff.dscalar.nii

    done

  done < $instructFile

  echo ""
  echo "DONE"
  echo "  seconds elapsed: $SECONDS"
  echo ""

fi


# clean-up
#rm -r $tmpDir
