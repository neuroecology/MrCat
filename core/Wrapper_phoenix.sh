#!/usr/bin/env bash
umask u+rw,g+rw # give group read/write permissions to all new files
set -e    # stop immediately on error

# TO PREPARE FOR THIS SCRIPT TO WORK:
# folder organisation:  - main_root/ > where the data folders for one species are with folder raw in it and where the init file is
# 						- main_root/templating > where the template pipeline will do its magic if setup
# instructInitConfig.txt into main_root/ to make with in order in one line and separated by a tab: 
# 	- name of the monkey folder, 
#   - the date of the scan, 
#   - if the brain is half or full,  
#	- if you need a specific nodif brain threshold, input 'nodthr' if want default 1000 (setup important for half brain)
#	- if you need to mask out some artefact (like vitaminE capsule), input 'makout' if don't need, save the mask in scripts folder (with config files)
# 	- the swapdim dimension (x y z), 
#   - stuff to extend the field of view: the dimension (x,y,z) and number of slices (no need if making template)
#   - the matrix for the transformation to acpc (must be in transform)
#   - the offset to the anterior commissure
# 	- the prepad of the sensm file,
#   - the bvecs number
# can copy a line like this and edit
# name	data	halfull    nodthr   maskout    dimx dimy dimz    exdim	exnum    mat    offx offy offz	rawfolder   prepad    bvecs1 bvecs2 bvecsn


# GENERAL SETTINGS
main_root=~/scratch/primates_comp/lemur/
script_dir=~/scratch/primates_comp/scripts

# SETTINGS FOR INIT_CONF
spaceconf="acpc"
# orig, swapdim or acpc

taskconf="inittemplate"
# all = "initbvecsROB initdMRIROB createnodif biascorrnodif dtifit flip_bvecs_x swapdim dtifit maskout extend_image_dim acpc setorigin dtifit"
# set to all only if have already all the settings

template="--template"
# nothing or -tp/--template
# TEMPLATE? Are these data used for future template? (to set up from step 5)

cluster=""
# nothing or jalapeno
# if you're running onto the cluster, can chose the queue as well
queue="long"

# Usually doing these in the following order, I have also indicated when I would switch space and when I would indicate template on the left.
# the script checks_outputs.sh (task indicated in parenthesis) opens the correct images to check output or define swapdim, maskout, acpc, origin
# 				1. initbvecsROB initdMRIROB createnodif biascorrnodif dtifit
# 				2. checks (nodif_V1) your nodif, dti_FA, dti_V1 for swapdim dimension and if flip-bvecs is needed
# 				3. flip_bvecs_x swapdim dtifit in swapdim
# 				4. checks (swapdim_mask) that it went well and do a mask if needed for maskout
# swapdim		4b. maskout (if needed)
# template		5. extend_image_dim after having run the check_fov script if doing templating
# 				6. make the acpc transform (acpc_transfo)
# 				7. acpc
# acpc			8. look at origin setoff (acpc_origin)
# 				9. setorigin
# 				10. dtifit in acpc
# 				11. Check all good (acpc_V1)
# 				(12. inittemplate, bedpostX)

# MAIN WRAPPER

# Launch Init_config

if [ $cluster = jalapeno ] ; then

	jinit=`fsl_sub -q veryshort.q -l $main_root/logs sh $script_dir/init_config.sh -r $main_root -s $spaceconf -t "${taskconf}"`
else
	sh $script_dir/init_config.sh -r $main_root -s $spaceconf -t "${taskconf}"
fi

# Get all the folders to do from init file and run the phoenix for them
# Instruct file
instructFile=$main_root/instructInitConfig.txt
while read -r name dataset bvecs ; do

	echo "doing name $name dataset $dataset task $taskconf"

	subj_folder=$main_root/$name

	if [ $cluster = jalapeno ] ; then

		echo "running on jalapeno cluster $queue queue"

		fsl_sub -q ${queue}.q -l $main_root/logs -j $jinit sh $script_dir/phoenix_LR $subj_folder/scripts/${dataset}.cnf $template

	else #locally

		sh $script_dir/phoenix_LR $subj_folder/scripts/${dataset}.cnf $template

	fi

	echo "preproc done for $name $dataset, task=$taskconf"

done < $instructFile  # read instructions line by line
