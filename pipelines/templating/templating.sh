#!/bin/bash

# Main script to apply the template pipeline from Rick Lange
# Revisited by Lea to be more general
# Could be launch from the Wrapper


# ------------------------------ #
# usage
# ------------------------------ #

usage() {
cat <<EOF

templating.sh: run the template pipeline to make multimodal template from dtifit output nodif and dti_tensor

Usage:    sh templating.sh -r </main_path/> -t <tasks> -m </morf_path/> -i <iter_nb>

Example:  sh templating.sh -r /main_path/ -t "apply_mask"

Main arguments:
  -r </main_path/>     path to main root with the /subs/ folder and each subject folder with nodif and dti_tensor to start with
  -t <tasks>   Tasks to perform in templating, if several tasks to be defined in between " "
  task could be: "finish_mask apply_mask bias_corr norm_int init_targ aff_reg create_temp_0 nonlin_reg unbias_warp create_temp"

Options:
  -m </morf_dir/> give the path to where mmorf.sif is, required for task="create_temp_0 nonlin_reg create_temp"
  -i <iteration_nb>  iteration number, could be set for task="nonlinereg unbiaswarp create_temp", 
  		but if not will check if files exist to determine which iteration to run and will increment

Tasks:
	finish_mask: after designing the mask, it is going to fill in the holes but better to check afterwards
	apply_mask: apply the mask for all subjects
	bias_corr: bias correct the t2 image using FAST
	norm_int: normalise intensities of all t2
	init_targ: take the first subject as the target (then unbias so no need to pick a specific one)
	aff_reg: perform the affine registration to random subject and unbias
	create_temp_0: create the first template (if want a nice acpc need to do the transform with nudge tool before)
	nonlin_reg: perform multimodal non linear registration (needs cuda queue)
	unbias_warp: unbias the warps
	create_temp: create template
  
EOF
}

#==============================
# overhead, argument parsing
#==============================

# if no arguments given, return the usage
if [[ $# -eq 0 ]] ; then usage; exit 0; fi

# parse the input arguments
while [[ $# -gt 0 ]] ; do
  case "$1" in
  	  -r|--mainroot)	main_root="$2"; shift 2 ;;
      -t|--task)    tasks="$2"; shift 2 ;;
      -m|--morf)    morf_dir="$2";    shift 2 ;;
      -i|--it)    iter="$2";    shift 2 ;;
	*) args=$(echo "$args" "$1"); shift ;; # either obligatory or unknown option
  esac
done

# CHECK FOR MANDATORY ARGUMENT
if [ -z $main_root ]; then echo "Error: you need to set up the main_root"; exit 1; fi
if [ -z $tasks ]; then echo "Error: you need to give some tasks to do"; exit 1; fi

# GENERAL SETTINGS
cwd=$(pwd)
iterations=("1a" "1b" "2a" "2b" "3a" "3b" "4a" "4b" "5a" "5b")

# ============================================
# loop over tasks
# ============================================

for task in $tasks; do

	echo ""
	echo "NOW Working on task: $task"
	echo ""

	# -----------------------------------------
	# finish mask
	# -----------------------------------------

	if [ $task = finish_mask ] ; then
		for sub_dir in $main_root/subs/*/; do
			echo ""
			echo "///////////////////////////////////////////////////////////"
			echo "In subject directory: $sub_dir"
			echo "Running fslmaths to polish the mask"
			echo "///////////////////////////////////////////////////////////"
			echo ""
			fslmaths $sub_dir/mask -dilM $sub_dir/mask # dilate to  make sure the hole can be filled later
			fslmaths $sub_dir/mask -fillh $sub_dir/mask # refill the holes
			fslmaths $sub_dir/mask -eroF $sub_dir/mask # erode to make the mask tight

			echo "Check the final mask on FSLeyes"

			# echo "Fsleyes to check the mask"
			# fsleyes $sub_dir/dti_MD $sub_dir/mask -cm Yellow &

		done
	fi

	# -----------------------------------------
	# apply mask
	# -----------------------------------------

	if [ $task = apply_mask ] ; then

		for sub_dir in $main_root/subs/*/; do
		  echo ""
		  echo "///////////////////////////////////////////////////////////"
		  echo "In subject directory: $sub_dir"
		  echo "Running fslmaths to apply mask"
		  echo "///////////////////////////////////////////////////////////"
		  echo ""
		  fslmaths $sub_dir/nodif -mul $sub_dir/mask $sub_dir/t2_masked
		  fslmaths $sub_dir/dti_tensor -mul $sub_dir/mask $sub_dir/dti_masked
		done

	fi

	# -----------------------------------------
	# bias correction
	# -----------------------------------------

	if [ $task = bias_corr ] ; then
		for sub_dir in $main_root/subs/*/; do
		  echo ""
		  echo "///////////////////////////////////////////////////////////"
		  echo "In subject directory: $sub_dir"
		  echo "Running FAST bias correction"
		  echo "///////////////////////////////////////////////////////////"
		  echo ""
		  mkdir -p $sub_dir/tmp
		  fast -n 3 -I 5 -O 0 -B -o $sub_dir/tmp/t2 $sub_dir/t2_masked
		  mv $sub_dir/tmp/t2_restore* $sub_dir/
		  rm -r $sub_dir/tmp
		done
	fi

	# -----------------------------------------
	# normalise itensities
	# -----------------------------------------

	if [ $task = norm_int ] ; then

		for sub_dir in $main_root/subs/*/; do
		  echo ""
		  echo "///////////////////////////////////////////////////////////"
		  echo "In subject directory: $sub_dir"
		  echo "Running fslmaths image normalisation"
		  echo "///////////////////////////////////////////////////////////"
		  echo ""
		  fslmaths $sub_dir/t2_restore -inm 1000 $sub_dir/t2_norm
		done
	fi

	# -----------------------------------------
	# create initial target
	# -----------------------------------------

	if [ $task = init_targ ] ; then

      	# getting the first subject
		subjList=($main_root/subs/*/)
		ref_subject=${subjList[0]}


		echo ""
		echo "///////////////////////////////////////////////////////////"
		echo "Here we choose a random subject as the initial template."
		echo "Which one we choose is unimportant as we will unbias the"
		echo "affine template."
		echo "///////////////////////////////////////////////////////////"
		echo ""
		mkdir -p $main_root/templates
		cp $ref_subject/t2_norm.nii.gz $main_root/templates/random_subject.nii.gz
		fslmaths $main_root/templates/random_subject.nii.gz -mul 0 $main_root/templates/ref_space -odt float

	fi

	# -----------------------------------------
	# affine register
	# -----------------------------------------

	if [ $task = aff_reg ] ; then
		for sub_dir in $main_root/subs/*/; do
		  echo ""
		  echo "///////////////////////////////////////////////////////////"
		  echo "In subject directory: $sub_dir"
		  echo "Running flirt affine registration"
		  echo "///////////////////////////////////////////////////////////"
		  echo ""
		  flirt -in $sub_dir/t2_norm -ref $main_root/templates/random_subject -out $sub_dir/t2_norm_aff_rand -omat $sub_dir/affine_to_random.mat
		done
	
		echo ""
		echo "///////////////////////////////////////////////////////////"
		echo "Finding mid-affine transformation"
		echo "///////////////////////////////////////////////////////////"
		echo ""
		mkdir -p $main_root/mats
		midtrans -o $main_root/mats/mid_trans.mat --template=$main_root/templates/random_subject `ls $main_root/subs/*/affine_to_random.mat`

		for sub_dir in $main_root/subs/*/; do
		  echo ""
		  echo "///////////////////////////////////////////////////////////"
		  echo "In subject directory: $sub_dir"
		  echo "Unbiasing affine and warping t2 to mid-space"
		  echo "///////////////////////////////////////////////////////////"
		  echo ""
		  convert_xfm -omat $sub_dir/affine_to_random_unbiased.mat -concat $main_root/mats/mid_trans.mat $sub_dir/affine_to_random.mat
		  applywarp -i $sub_dir/t2_norm -o $sub_dir/t2_affine_to_mid -r $main_root/templates/ref_space --premat=$sub_dir/affine_to_random_unbiased.mat --interp=spline
		done

		echo ""
		echo "///////////////////////////////////////////////////////////"
		echo "Creating unbiased affine template."
		echo "This can be manually straightened if necessary."
		echo "Open templates/t2_affine_mid and use nudge tool"
		echo "Save it as mats/straighten_affine_mid.mat"
		echo "///////////////////////////////////////////////////////////"
		echo ""

		subjList=($main_root/subs/*/) # get the subject array
		sLen=${#subjList[@]} # get the length
		lastsubj=${subjList[$sLen-1]} # get the last subject
		unset 'subjList[$sLen-1]' # remove last subject

		# make the fslmaths command
		command=""

		for i in "${!subjList[@]}"; do
			command+="${subjList[i]}/t2_affine_to_mid -add "
		done

		command+="$lastsubj/t2_affine_to_mid -div $sLen $main_root/templates/t2_affine_mid"

		fslmaths $command
	fi

	# # -----------------------------------------
	# # create template iteration 0
	# # -----------------------------------------

	if [ $task = create_temp_0 ] ; then

		if [ -z $morf_dir ]; then echo "Error morf_dir not defined for task create_temp_0"; exit 1; fi

		if [ ! -f $main_root/mats/straighten_affine_mid.mat ]; then
			echo "WARNING: no mats/straighten_affine_mid.mat found so using an identity matrix"
			echo "It is better to make a matrix to have a nice acpc space"
			cp $main_root/mats/identity.mat $main_root/mats/straighten_affine_mid.mat
		fi

		for sub_dir in $main_root/subs/*/; do
		  echo ""
		  echo "///////////////////////////////////////////////////////////"
		  echo "In subject directory: $sub_dir"
		  echo "Combining affines"
		  convert_xfm -omat $sub_dir/affine.mat -concat $main_root/mats/straighten_affine_mid.mat $sub_dir/affine_to_random_unbiased.mat
		  echo "Running applywarp"
		  mkdir -p $sub_dir/iter_0
		  applywarp -i $sub_dir/t2_norm -o $sub_dir/iter_0/t2_warped -r $main_root/templates/ref_space --premat=$sub_dir/affine.mat --interp=spline
		  echo "Running vecreg"
		  vecreg -i $sub_dir/dti_masked -o $sub_dir/iter_0/dti_warped -r $main_root/templates/ref_space -t $sub_dir/affine.mat --interp=spline
		  echo ""
		done

		echo ""
		echo "///////////////////////////////////////////////////////////"
		echo "Running fslmaths to average t2 images"

		subjList=($main_root/subs/*/) # get the subject array
		sLen=${#subjList[@]} # get the length
		lastsubj=${subjList[$sLen-1]} # get the last subject
		unset 'subjList[$sLen-1]' # remove last subject

		# make the fslmaths command
		command=""
		for i in "${!subjList[@]}"; do
			command+="${subjList[i]}/iter_0/t2_warped -add "
		done

		command+="$lastsubj/iter_0/t2_warped -div $sLen $main_root/templates/t2_iter_0"
		fslmaths $command


		echo "Running tensor_average to average dti images"

		# make the singularity command
		subsList=$(find $main_root/subs/. -type d -mindepth 1 -maxdepth 1 -exec basename {} \;)
		command_sing=""
		for sub in $subsList; do
			command_sing+="$main_root/subs/$sub/iter_0/dti_warped "
		done

		singularity exec --bind $morf_dir,$main_root $morf_dir/mmorf.sif tensor_average -i \
		$command_sing \
		-o $main_root/templates/dti_iter_0
		echo "///////////////////////////////////////////////////////////"
		echo ""

		iter="1a"
		echo "Now set iteration to $iter"

	fi

	# # -----------------------------------------
	# # non linear register
	# # -----------------------------------------

	if [ $task = nonlin_reg ] ; then

		if [ -z $morf_dir ]; then echo "Error morf_dir not defined for task create_temp_0"; exit 1; fi

		if [ -z $iter ]; then
			# check if files from previous iterations have been made

			for it in ${iterations[@]}; do
				for sub_dir in $main_root/subs/*/; do
					if [ -f $sub_dir/iter_${it}/warp.nii.gz ] && [ -f $sub_dir/iter_${it}/jac.nii.gz ]; then
						echo "files for iter $it found in $sub_dir"
						continue
					elif [ ! -f $sub_dir/iter_${it}/warp.nii.gz ]; then
					    echo "warp not found for iter $it in $sub_dir!"
					    iter_nb=$it
					    break 2
					elif [ ! -f $sub_dir/iter_${it}/jac.nii.gz ]; then
					    echo "jac not found for iter $it in $sub_dir!"
					    iter_nb=$it
					    break 2
					fi
				done
			done

		elif [ ! -z $iter ]; then
			iter_nb=$iter
		fi

		echo "doing $task at iteration $iter_nb"
		if [ ! -f $main_root/config/iter_${iter_nb}.ini ]; then echo "Error no config file for task $task iter $iter_nb"; exit 1; fi

		# Loop over subjects and run MMORF on each one
		for sub_dir in $main_root/subs/*/; do
		  cd $sub_dir
		  echo ""
		  echo "///////////////////////////////////////////////////////////"
		  echo "In subject directory: $sub_dir"
		  echo "Running mmorf"
		  mkdir -p iter_${iter_nb}
		  singularity run \
		    --nv \
		    --bind $morf_dir,$main_root \
		    $morf_dir/mmorf.sif --config $main_root/config/iter_${iter_nb}.ini
		  echo "///////////////////////////////////////////////////////////"
		  echo ""
		  cd $cwd
		done

		iter=$iter_nb

		echo "Iteration is still $iter"

	fi

	# # -----------------------------------------
	# # unbias warp
	# # -----------------------------------------

	if [ $task = unbias_warp ] ; then

		if [ -z $iter ]; then
			# check if files from previous iterations have been made

			for it in ${iterations[@]}; do
				for sub_dir in $main_root/subs/*/; do
					if [ -f $sub_dir/iter_${it}/warp_combined.nii.gz ]; then
						echo "file for iter $it found in $sub_dir"
						continue
					elif [ ! -f $sub_dir/iter_${it}/warp_combined.nii.gz ]; then
					    echo "warp not found for iter $it in $sub_dir!"
					    iter_nb=$it
					    break 2
					fi
				done
			done

		elif [ ! -z $iter ]; then
			iter_nb=$iter
		fi

		echo "doing $task at iteration $iter_nb"

		# Create average warp and invert it then unbias warps
		echo ""
		echo "///////////////////////////////////////////////////////////"
		echo "Running fslmaths to average warps"
		mkdir -p $main_root/warps

		subjList=($main_root/subs/*/) # get the subject array
		sLen=${#subjList[@]} # get the length
		lastsubj=${subjList[$sLen-1]} # get the last subject
		unset 'subjList[$sLen-1]' # remove last subject

		# make the fslmaths command
		command=""
		for i in "${!subjList[@]}"; do
			command+="${subjList[i]}/iter_${iter_nb}/warp -add "
		done

		command+="$lastsubj/iter_${iter_nb}/warp -div $sLen $main_root/warps/average_warp_iter_${iter_nb}"
		fslmaths $command

		echo "Running invwarp to invert average warp"
		invwarp -w $main_root/warps/average_warp_iter_${iter_nb} -o $main_root/warps/inv_average_warp_iter_${iter_nb} -r $main_root/templates/ref_space -v
		echo "///////////////////////////////////////////////////////////"
		echo ""

		for sub_dir in $main_root/subs/*/; do
		  echo ""
		  echo "///////////////////////////////////////////////////////////"
		  echo "In subject directory: $sub_dir"
		  echo "Running applywarp to resample biased warp"
		  applywarp -i $sub_dir/iter_${iter_nb}/warp -o $sub_dir/iter_${iter_nb}/warp_resampled -r $main_root/templates/ref_space -w $main_root/warps/inv_average_warp_iter_${iter_nb} --interp=spline
		  echo "Running fslmaths to create unbiased warp"
		  fslmaths $sub_dir/iter_${iter_nb}/warp_resampled -add $main_root/warps/inv_average_warp_iter_${iter_nb} $sub_dir/iter_${iter_nb}/warp_unbiased
		  echo "Running convertwarp to combine affine and nonlinear"
		  convertwarp --ref=$main_root/templates/ref_space --premat=$sub_dir/affine.mat --warp1=$sub_dir/iter_${iter_nb}/warp_unbiased --out=$sub_dir/iter_${iter_nb}/warp_combined
		  echo "///////////////////////////////////////////////////////////"
		  echo ""
		done

		iter=$iter_nb
		
		echo "Iteration is still $iter"

	fi

	# # -----------------------------------------
	# # create template
	# # -----------------------------------------

	if [ $task = create_temp ] ; then

		if [ -z $morf_dir ]; then echo "Error morf_dir not defined for task create_temp_0"; exit 1; fi

		if [ -z $iter ]; then
			# check if files from previous iterations have been made

			for i in ${!iterations[@]}; do
				it=${iterations[$i]}
				if [ -f $main_root/templates/t2_iter_${it}.nii.gz ] && [ -f $main_root/templates/t2_iter_${it}.nii.gz ]; then
					echo "files for iter $it found"
					continue
				elif [ ! -f $main_root/templates/t2_iter_${it}.nii.gz ]; then
				    echo "t2 not found for iter $it in templates!"
				    iter_nb=$it
				    j=$i
				    break 1
				elif [ ! -f $main_root/templates/dti_iter_${it}.nii.gz ]; then
				    echo "dti not found for iter $it in templates!"
				    iter_nb=$it
				    j=$i
				    break 1
				fi
			done

		elif [ ! -z $iter ]; then
			iter_nb=$iter
			for i in ${!iterations[@]}; do
				it=${iterations[$i]}
				if [ $it = $iter_nb ] ; then
					j=$i
				fi
			done
		fi

		echo "doing $task at iteration $iter_nb"

		# Loop over subjects and apply mmorf warp to create template
		for sub_dir in $main_root/subs/*/; do
		  echo ""
		  echo "///////////////////////////////////////////////////////////"
		  echo "In subject directory: $sub_dir"
		  echo "Running applywarp"
		  applywarp -i $sub_dir/t2_norm -o $sub_dir/iter_${iter_nb}/t2_warped -r $main_root/templates/ref_space -w $sub_dir/iter_${iter_nb}/warp_combined  --interp=spline
		  echo "Running vecreg"
		  vecreg -i $sub_dir/dti_masked -o $sub_dir/iter_${iter_nb}/dti_warped -r $main_root/templates/ref_space -w $sub_dir/iter_${iter_nb}/warp_combined --interp=spline
		  echo ""
		done


		echo ""
		echo "///////////////////////////////////////////////////////////"
		echo "Running fslmaths to average t2 images"

		subjList=($main_root/subs/*/) # get the subject array
		sLen=${#subjList[@]} # get the length
		lastsubj=${subjList[$sLen-1]} # get the last subject
		unset 'subjList[$sLen-1]' # remove last subject

		# make the fslmaths command
		command=""
		for i in "${!subjList[@]}"; do
			command+="${subjList[i]}/iter_${iter_nb}/t2_warped -add "
		done

		command+="$lastsubj/iter_${iter_nb}/t2_warped -div $sLen $main_root/templates/t2_iter_${iter_nb}"
		fslmaths $command


		echo "Running tensor_average to average dti images"

		# make the singularity command
		subsList=$(find $main_root/subs/. -type d -mindepth 1 -maxdepth 1 -exec basename {} \;)
		command_sing=""
		for sub in $subsList; do
			command_sing+="$main_root/subs/$sub/iter_${iter_nb}/dti_warped "
		done

		singularity exec --bind $morf_dir,$main_root $morf_dir/mmorf.sif tensor_average -i \
		$command_sing \
		-o $main_root/templates/dti_iter_${iter_nb}
		echo "///////////////////////////////////////////////////////////"
		echo ""

		if [ $iter = 5b ]; then
			echo "last iteration done"

		else
			iter=${iterations[j+1]}
			echo "Now set iteration to $iter"
		fi

	fi


done