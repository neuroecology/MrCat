#### General information

This is a suggested pipeline for resting state fMRI data obtained in macaques at the University of Oxford's Biomedial Sciences Building (BSB). Created by members of the Cognitive Neuroecology lab. This pipeline is mostly written by Rogier Mars, but relies heavily on scripts written by Lennart Verhagen and Davide Folloni.

#### Setup

This document describes the (simplified) macaque resting state fMRI pipeline.

The pipeline assumes the following directory structure:

<pre><code>
studydir ---- subj1 ---- functional
		  |		 	 |
		  |		 	 ---- structural
		  |
		  --- subj2 ---- functional		 
		  		 	 |
		  			 ---- structural
</code></pre>

It is assumed there is a file struct.nii.gz in the structural directory containing the unbetted structural and a file raw.nii.gz in the functional directory containing the fMRI resting state time series.

MrCat-dev and wb_command are required. Pipeline relies on MrCat-dev/pipelines/rfmri_macaque, MrCat-dev/data/macaque, and MrCat-dev/core/struct_macaque.sh

---
#### Running

The idea is that the pipeline is modular, so that it easy to add and remove parts. The only editing required should be in `rsn_pipeline.m` where the study directory, subject name, and task list is specified. Then just run `rsn_pipeline.m` and it will loop across tasks.

You should hopefully have to edit the setting of each individual step only once for each specific study, and then you can use the task list to run the required bits for each subjecct.

Some notes on the individual steps and the recommended order:

##### reorient_struc

This is specific to the standard orientation of Oxford BSB in-vivo scans and aims to get AP, SI, and LR orientation correct for FSL.

##### bet_and_register_struct

Skull-strip the structural brain and register it to F99 space using `struct_macaque.sh` from the in_vivo structural pipeline. Warpfields will be placed in the 'tranform' directory.

##### reorient_func

This is specific to the standard orientation of Oxford BSB in-vivo scans and aims to get AP, SI, and LR orientation correct for FSL.

##### func_bet

Skull-stripping of the functional data is done using Lennart's `bet_macaque.sh`. Most likely some of the parameters needs to be tweaked for a specific dataset.

##### coreg_func_struct

Using Lennart's `register_EPI_T1.sh` the functional and structural are aligned as well as possible. This is necessary for future steps where the functional data is warped to F99 space via the structural. Also creates and example_func.nii.gz in the functional directory.

##### filter

The resting state fMRI data from Oxford has strong respiratory artifacts that are generally filtered out using FSL's `fslmaths`.

##### regressout_CSFWM

The dominant time courses of the white matter and CSF often explain quite a lot of variance in resting state data and are there often included as confound regressors. Here instead we simply regress out these time courses. The the bias corrected structural scan from the bet_and_register_struct step above (struct_brain_restore) is segmented using FSL's `fast` algorithm, the white matter and CSF masks are flirted to the functional space using the transformation matrices of the coreg_func_struct step above and the dominant time courses are extracted using `fslmeants`. This is all done using `rsn_regressoutCSFWM.sh` which then calls the Matlab script `rsn_regressoutCSFWM.m` which does the actual regression using `regress_out.m` in MrCat's general directory.

##### dtseries

`rsn_func2dtseries.sh` warps functional data to standard space via the structural and therefore requires bet_and_register_struc to have run. Using wb_command, data are then projected to the surface as func.gii GIFTI files and converted to CIFTI dtseries. To save space, the in-between GIFTI files are removed, but the dtseries and dconn are retained. Use `--fullcleanup` to remove all intermediate stages.

##### normalize_ts

`rsn_normalise_ts.m` normalizes each times series to zero mean and std=1. This implementation can handle both volume (.nii.gz) and surface (.dtseries.nii) based data. It relies on `normalise.m` in MrCat's general directory.

##### smooth_dtseries

This uses wb_command to smooth the surface dtseries.

##### dtseries2dconn

This uses wb_command to simply calculate to correlation of a dtseries to a dconn

##### dconn

`rsn_func2donn.sh` warps functional data to standard space via the structural and therefore requires bet_and_register_struc to have run. Using wb_command, data are then projected to the surface as func.gii GIFTI files, converted to CIFTI dtseries and finally correlated to CIFTI dconn. To save space, the in-between GIFTI files are removed, but the intermediate warp fields are removed. Use `--fullcleanup` to remove all intermediate stages. Depreciated now, best to do dtseries instead, so you can perform other processing steps (e.g., smoothing) on the surface time series.

---
#### Additional features

The iterative group_PCA of resting state data (Smith et al., 2014, NeuroImage) is implemented using `MIGP.m`.

---

#### Known issues and future developments

ICA-based denoising is currently not implemented.

Removing of physiological signals is currently not implemented.
