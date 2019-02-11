#!/usr/bin/env bash
umask u+rw,g+rw # give group read/write permissions to all new files
set -e    # stop immediately on error


# ------------------- #
# GENERAL DEFINITIONS
# ------------------- #
source $MRCATDIR/setupMrCat.sh
studyDir="/Volumes/rsfMRI/anaesthesia"
anaDir="$studyDir/analysis"
mkdir -p $anaDir/map

# try to retrieve the dataset suffices, or opt for defaults
[[ -f $anaDir/instruct/sourceConfig.sh ]] && source $anaDir/instruct/sourceConfig.sh
[[ -z $suffixClean ]] && suffixClean="WMCSF"
[[ -z $suffixConn ]] && suffixConn=".clean${suffixClean}"

# retrieve the instruction file
instructFile=$anaDir/instruct/instructCompareMaps.txt
[[ ! -s $instructFile ]] && echo "" && >&2 printf "\nError: no valid instruction file found at:\n%s\n\n" $instructFile && exit 1
[[ $(tail -c1 $instructFile | wc -l) -le 0 ]] && echo "" >> $instructFile

# start a timer
SECONDS=0


# -------------------------- #
# COMPARING WHOLE-BRAIN MAPS
# -------------------------- #
echo ""
echo "COMPARING WHOLE-BRAIN MAPS"


# loop over FUN sites
while read -r mapName siteNameA varArgIn1 varArgIn2 ; do
  echo ""

  # set comparison based on content of variable arguments
  if [[ $varArgIn1 =~ ^\.|^_ ]] ; then
    # comparing differently processed data from the same site
    siteNameB=$siteNameA
    suffixConnA=$varArgIn1
    suffixConnB=$varArgIn2
    seedNameList=""
    mapOutBase=${siteNameA}${suffixConnA}${suffixConnB}.$mapName
    echo "  comparing \"$mapName\" maps from \"$siteNameA\" between \"$suffixConnA\" and  \"$suffixConnB\""
  else
    # comparing similarly processed data from different sites
    siteNameB=$varArgIn1
    suffixConnA=$suffixConn
    suffixConnB=$suffixConn
    seedNameList=$varArgIn2
    mapOutBase=${siteNameA}.${siteNameB}${suffixConnA}.$mapName
    echo "  comparing \"$mapName\" maps from \"$siteNameA\" with \"$siteNameB\""
  fi

  # change processing pipeline depending on map type
  if [[ $mapName == "sbca" ]] || [[ $mapName == "SBCA" ]] ; then

    # specify the seed-based connectivity maps
    sbcaA=$anaDir/sbca/group/${siteNameA}${suffixConnA}.sbca.dscalar.nii
    sbcaB=$anaDir/sbca/group/${siteNameB}${suffixConnB}.sbca.dscalar.nii

    # compile a list of connectivity maps available for each site
    mapListA=$(wb_command -file-information $sbcaA -only-map-names)
    mapListB=$(wb_command -file-information $sbcaB -only-map-names)

    # contrast either all maps or a selection
    if [[ -z $seedNameList ]] ; then

      # absolute difference
      mapOut=$anaDir/sbca/group/$mapOutBase.diff.dscalar.nii
      wb_command -cifti-math "(B-A)" $mapOut -fixnan 0 -var "A" $sbcaA -var "B" $sbcaB > /dev/null

      # relative difference
      mapOut=$anaDir/sbca/group/$mapOutBase.diffP.dscalar.nii
      wb_command -cifti-math "(100*((B-A)/A))" $mapOut -fixnan 0 -var "A" $sbcaA -var "B" $sbcaB > /dev/null

    else

      # loop over seeds (comma-separated)
      for seedName in ${seedNameList//,/ } ; do

        # assume a bilateral seed, if not specified
        [[ ! $seedName =~ \. ]] && seedName=$seedName.bilat
        seedNameBase=$(echo ${seedName%%.*})

        # find column of the seed
        idxColA=$(echo "$mapListA" | awk '($1 == "'$seedName'"){print NR; exit}')
        idxColB=$(echo "$mapListB" | awk '($1 == "'$seedName'"){print NR; exit}')

        # absolute difference
        mapOut=$anaDir/sbca/group/$mapOutBase.diff.$seedNameBase.dscalar.nii
        wb_command -cifti-math "(B-A)" $mapOut -fixnan 0 -var "A" $sbcaA -select 2 $idxColA -var "B" $sbcaB -select 2 $idxColB > /dev/null

        # relative difference
        mapOut=$anaDir/sbca/group/$mapOutBase.diffP.$seedNameBase.dscalar.nii
        wb_command -cifti-math "(100*((B-A)/A))" $mapOut -fixnan 0 -var "A" $sbcaA -select 2 $idxColA -var "B" $sbcaB -select 2 $idxColB > /dev/null

      done

    fi

  else

    # specify the maps
    mapA=$anaDir/map/${siteNameA}${suffixConnA}.$mapName.dscalar.nii
    mapB=$anaDir/map/${siteNameB}${suffixConnB}.$mapName.dscalar.nii

    # absolute difference
    mapOut=$anaDir/map/$mapOutBase.diff.dscalar.nii
    wb_command -cifti-math "(B-A)" $mapOut -fixnan 0 -var "A" $mapA -var "B" $mapB > /dev/null

    # relative difference
    mapOut=$anaDir/map/$mapOutBase.diffP.dscalar.nii
    wb_command -cifti-math "(100*((B-A)/A))" $mapOut -fixnan 0 -var "A" $mapA -var "B" $mapB > /dev/null

  fi

done < $instructFile


echo ""
echo "DONE"
echo "  seconds elapsed: $SECONDS"
echo ""
