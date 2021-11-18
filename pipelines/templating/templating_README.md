Pipeline for multimodal template creation
----------------------------------------------------------------

Conference paper: Multimodal MRI Template Creation in the Ring-Tailed Lemur and Rhesus Macaque
Frederik J. Lange, Stephen M. Smith, Mads F. Bertelsen, Alexandre A. Khrapitchev, Paul R. Manger, Rogier B. Mars, and Jesper L.R. Andersson

Version history of this README.md:
28-07-2020 Lea created


GETTING STARTED
------------
Running the pipeline requires MrCat to be set up in your environment (see instructions in MrCat-dev/docs/setting_up_mr_cat.md).

For a given species the folder structure will look as follow: 

<pre><code>
speciesdir  ----   templating  ---- |  config
                                    |  mats
                                    |  subs ---- |  sub1
                                                 |  sub2 ...
                                    |  templates
                                    |  warps
</code></pre>

The /config/ folder needs to be created with the config files in it (config files provided in scripts/Template/config_example). 
The /subs/ folder and subjects subfolder should be present as well. You need to have for each subject at least the nodif.nii.gz and the dti_tensor.nii.gz from the output of dtifit (they are being called t2 (or scalar) and dti respectively). The MD.nii.gz could be useful to draw the first mask.
The other folders will be created during the pipeline.

You also need to have the mmorf.sif singularity virtual machine somewhere.

And you require an identity.mat in mats which could be created manually. It is simply a 4x4 identity matrix in a normal text file with the ".mat" extension.

The `templating.sh` script takes several arguments, it could be run from the `Wrapper_templating.sh`  which will deal with cluster option.

templating.sh:
Main arguments:
  -r path to main root with the /subs/ folder and each subject folder with nodif and dti_tensor to start with
  -t Tasks to perform in templating, if several tasks to be defined in between " "
  task could be: "finish_mask apply_mask bias_corr norm_int init_targ aff_reg create_temp_0 nonlin_reg unbias_warp create_temp"
Options:
  -m give the path to where mmorf.sif is, required for task="create_temp_0 nonlin_reg create_temp"
  -i iteration number, could be set for task="nonlinereg unbiaswarp create_temp", 
            but if not will check if files exist to determine which iteration to run and will increment

The outputs of this pipeline are the template images: t2_iter_5b and dti_iter_5b for each species and the warp to each individual. The template images have been copied into species/standard under t2_template and dti_iter_5b

STEPS IN THE PIPELINE
------------

Let's run through all the steps in the pipeline, so you can see what happens.

##The first part is mostly preprocessing

#####make a mask (manual)

This is the most manual part, which is going to depend a lot on the different subject data. You could make the mask using the MD image because it is easier to see the non-brain artefact.
Recommended steps to make the mask (could be diferent for different data):
-     Check if there is any artefact
-     Enter edit mode
-     Create an empty file  
-     Toggle the following editing command: select mode,select by intensities,3D,search space adjacent
-     Choose a voxel outside the artefact and in the MD brain (I recommend using a voxel of high intensity toward the outside of the brain)
-     Use the intensity threshold to set the correct area for the mask (you might have to toggle between the new file and the dti_MD)
-     While the new file is highlighted, fill in the area defined
-     Save it as ‘mask’ in each subject folder
If there are still some holes in the brain or the mask does not fit, you can use the following task (finish_mask)

#####finish_mask

This is a combination of commands, it is working on most subject but need to check quality of the mask after.
--> mask.nii.gz in each subject directory

#####apply_mask

Loop trough subjects to mask the T2 (nodif) and dti (tensor) image.
--> t2_masked.nii.gz, dti_masked.nii.gz in each subject directory

#####bias_corr

Loop trough subjects to remove bias field using FAST in the T2 image.
--> t2_restore.nii.gz in each subject directory

#####norm_int 

Loop trough subjects to normalise the intensities using fslmaths option -inm for T2 images. The normalisation takes place so that the intensities of one subject does not dominate the template. The mean value of the images is now set at 1000 arbitrarily. We can do this for the T2 image because the quantitative information is not of interest per se, but we cannot do it for the tensors.
--> t2_norm.nii.gz in each subject directory


##Now we will create the first affine template

#####init_targ

Here we choose a random subject as the initial template. Which one we choose is unimportant as we will unbias the affine template. The ref_space image is just to have an empty image with the correct dimensions and a meaningful name to use later.
--> templates/random_subject.nii.gz, templates/ref_space.nii.gz

#####aff_reg

First flirt trough the subjects, to register them to the random subject.
--> t2_norm_aff_rand, affine_to_random.mat in each subject directory

Then doing unbiasing steps:
Find mid-affine transformation between all subjects.
--> mats/mid_trans.mat

Then concatenate the warp from subject to biased and from biased to unbiased (the affine_to_random and the mid_trans) and apply this warp to each subject.
--> affine_to_random_unbiased.mat, t2_affine_to_mid in each subject directory 

Average the resulting across subject to obtain the very initial template.
--> templates/t2_affine_mid

#####make the transform to acpc (manual)

This affine template can be manually straightened if necessary to look like acpc space. Open templates/t2_affine_mid and use nudge tool to put the [ 0 0 0 ] at acpc. Save it as mats/straighten_affine_mid.mat, if unset it will just use an identity.mat

#####create_temp_0

Loop trough subjects to applywarp to ref space using affine.mat (combined affine_to_random_unbiased.mat and straighten_affine_mid.mat) for t2 and similarly with dti but using vercreg instead of applywarp because of tensor information.
--> iter_0/t2_warped.nii.gz, iter_0/dti_warped.nii.gz for each subject directory

Then average the t2 images using fslmaths
--> templates/t2_iter_0.nii.gz

And average the dti images using mmorf tensor average function, which is performing the tensor averaging in log space. This part needs to be run on the cluster because it uses singularity mmorf.sif
--> templates/dti_iter_0.nii.gz

##Now are the three steps hapening at each iteration of the non-linear registration

For now we have hard-coded that there will be 10 iterations, 2 at each level of resolution ("1a" "1b" "2a" "2b" "3a" "3b" "4a" "4b" "5a" "5b"). You can either chose only one iteration or in the wrapper you can setup the script to do all iterations from the next one needed (set nothing for iter paramter) and as many of the three steps you want (one for each iteration in order).

#####nonlin_reg
NEEDS TO BE RUN ON CUDA

First make sure you have the config file corresponding to the iteration in /config/ folder (ex for iteration 1a: init_1a.ini). This step takes some time, this is where the main registration is done using mmorf.sif.
--> iter_1a/warp, iter_1a/jac for each subject directory

#####unbias_warp

Need to do unbiasing because the template can end up being slightly biased where one subject needs to move more to match the template than others. So do average warp so that each subject moves the same amount to match the template. 
--> warps/average_warp_iter_1a

Then inverse this warp (was from biased to unbiased, no is from unbiased to biased)
--> warps/inv_average_warp_iter_1a

Then for each subject resample the initial warp and add it too the inv_warp to get the unbiased warp, finally concatenate it with the affine.mat.
--> iter_1/warp_resampled, iter_1a/warp_unbiased, iter_1a/warp_combined for each subject directory

#####create_temp

Apply the warp created before to each subject, so we obtained a t2 and dti in ref space for each subject and average them. This part needs to be run on the cluster because it uses singularity mmorf.sif
--> iter_1a/t2_warped, iter_1a/dti_warped, templates/t2_iter_1a, templates/dti_iter_1a

