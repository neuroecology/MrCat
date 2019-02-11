# offlineTUS
This is an open-source repository with the code supporting the publication:

## Offline impact of transcranial focused ultrasound on cortical activation in primates  

#### Lennart Verhagen<sup>1,2</sup>\*, Cécile Gallea<sup>3</sup>\*, Davide Folloni<sup>1,2</sup>, Charlotte Constans<sup>4</sup>, Daria EA Jensen<sup>1,2</sup>, Harry Ahnine<sup>3</sup>, Léa Roumazeilles<sup>1,2</sup>, Mathieu D Santin<sup>3</sup>, Bashir Ahmed<sup>5</sup>, Stéphane Lehericy<sup>3</sup>, Miriam Klein-Flügge<sup>1,2</sup>, Kristine Krug<sup>5</sup>, Rogier B Mars<sup>2,6</sup>, Matthew F.S. Rushworth<sup>1,2</sup>†, Pierre Pouget<sup>7</sup>†, Jean-François Aubry<sup>4</sup>†, Jérôme Sallet<sup>1,2</sup>†  

<sup>1</sup> Wellcome Centre for Integrative Neuroimaging (WIN), Department of Experimental Psychology, University of Oxford, Oxford OX1 3SR, UK  
<sup>2</sup> Wellcome Centre for Integrative Neuroimaging (WIN), Centre for Functional MRI of the Brain (FMRIB), Nuffield Department of Clinical Neurosciences, John Radcliffe Hospital, University of Oxford, Oxford OX3 9DU, UK  
<sup>3</sup> Institute du Cerveau et de la Moelle épinière (ICM), Centre for NeuroImaging Research (CENIR), Inserm U 1127, CNRS UMR 7225, Sorbonne Université, F-75013, Paris, France  
<sup>4</sup> Institut Langevin, ESPCI Paris, PSL Research University, CNRS 7587, INSERM U979, Sorbonne Université, Paris, France  
<sup>5</sup> Department of Physiology, Anatomy, and Genetics, University of Oxford, Oxford, OX1 3PT, UK  
<sup>6</sup> Donders Institute for Brain, Cognition and Behaviour, Radboud University Nijmegen, 6525 HR Nijmegen, the Netherlands  
<sup>7</sup> Institute du Cerveau et de la Moelle épinière (ICM), UMRS 975 INSERM, CNRS 7225, UMPC, Paris, France   

\* These authors contributed equally  
† These authors contributed equally  

Correspondence:  
lennart.verhagen@psy.ox.ac.uk  
jerome.sallet@psy.ox.ac.uk  

Data can be downloaded from:
https://git.fmrib.ox.ac.uk/lverhagen/offlinetus


## start-up instructions

When in Oxford, rs-fMRI TUS data can be found here:  
/Volumes/rsfMRI/anaesthesia/proc  
/Volumes/rsfMRI/anaesthesia/analysis  
/Volumes/rsfMRI/structural  

##### When new data arrives:
1. add the functional data to /Volumes/rsfMRI/anaesthesia/orig/
2. add the structural data to /Volumes/rsfMRI/structural/proc/
3. add the session details to /Volumes/rsfMRI/anaesthesia/proc/instruct/instructGood.txt


## data organisation

##### data organisation at start of pipeline:  
projectDir/structural/proc/monkey1/session1/struct.nii.gz
projectDir/functional/proc/instruct/instructGood.txt
projectDir/functional/orig/monkey1/session1/rfMRI_orig_run1.nii.gz
projectDir/functional/orig/monkey1/session1/rfMRI_orig_run2.nii.gz
projectDir/functional/orig/monkey1/session1/rfMRI_orig_run3.nii.gz

*please note that InitStruct.sh is deprecated and therefore the structural image is already manually placed in the 'proc' folder before you start the pipeline*

##### the pipeline will create:  
projectDir/structural/proc/instruct/instructProcStruct.txt
projectDir/structural/proc/monkey1/session1/struct_restore.nii.gz, etc
projectDir/functional/proc/instruct/instructProcFunc.txt, etc
projectDir/functional/proc/monkey1/session1/func_run1.nii.gz, etc


## pipeline wrappers
The following scripts are wrappers to interact with the macaque resting fMRI processing pipeline of MrCat ($MRCATDIR/pipelines/rfmri_macaque). Nothing works if you do not have MrCat set up properly. Data and code folders have been hard-coded, as have been a few other settings. As such, please regard these scripts as examples rather than the divine word.

**SetupInstruct.sh [site_of_session]**  
  create a set of instructions for functional processing scripts (for example:
  instructInitFunc.txt, instructCheckFunc.txt) based on
  /Volumes/rsfMRI/proc/instruct/instructGood.txt. Alternatively, those
  instructions files can be created by hand by selecting lines from
  instructGood.txt.

**ProcStruct.sh**  
  preprocess the structural image for each monkey using struct_macaque

**InitFunc.sh**  
  copy and rename the original rs-fMRI data into a processing structure

**ProcFunc.sh**  
  preprocess the resting-state functional data  
  [here be dragons]

**PlotSMAPE.m**  
  little matlab script to plot the symmetric mean absolute error

**sourceConfig.sh**  
  please set the dataset suffices in [analysisDir]/instruct/sourceConfig.sh
  this little script will be sourced in all subsequent shell scripts

**MergeFunc.sh**  
  merge the runs and monkeys to create "average" connectomes

**CreateRoi.sh**  
  create regions-of-interest

**SeedConn.sh**  
  extract connectivity maps from ROIs

**ExtractFingerprint.sh**  
  extract connectivity fingerprints from ROIs

**AnalyseFingerprint.m**  
  processes and plots fingerprint (Matlab)

**DenseConn.sh**  
  calculate dense connectome: whole-brain x whole-brain connectivity

**QuantifyGlobalConn.m**  
  extract connectivity-strength whole-brain maps (e.g. at 98% of full range)

**ScaleDenseConn.sh**  
  calculate scaling between dense connectomes
  this is now probably obsolete, being replaced by RegressDenseConn.m

**RegressDenseConn.m**  
  calculate additive and multiplicative differences between dense connectomes
