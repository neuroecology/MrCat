The MR Comparative Anatomy Toolbox (Mr Cat) is a collection of bash shell and Matlab scripts and functions developed by members and collaborators of the Cognitive Neuroecology Lab at the Radboud University Nijmegen and the University of Oxford. It contains code that we have used to process and analyze magnetic resonance imaging data obtained from different types of brains. At the moment, only a limited set of scripts and functions is available, namely those that support published work. This will hopefully develop as new code is created and the associated papers published. Note that the code here on GitHub might differ from the code used for the papers, as we aim to keep updating all scripts and functions. Please note that all code are made available completely at your own risk. See also LICENSE.md.

Some notable features include:
- core/phoenix, a module for preprocessing post-mortem diffusion MRI data (cf. Mars et al., 2016, Brain Struct Funct)
- pipelines/templating, a module using FSL's MMORF for creating MRI templates for new species (cf. Roumazeilles et al., 2021, Brain Struct Funct)
- 'spider matching', sm_* matlab functions for comparing connectivity profiles (cf. Mars et al., 2016, Neurosci Biobehav Rev)
- connectivity gradients, conngrads_* matlab functions for gradient analyses of diffusion MRI tractography data (cf. Blazquez Freches et al., 2021, Hum Brain Mapp)

When using Mr Cat, please cite the Mars et al., 2016, Neurosci Biobehav Rev paper and the papers of the relevant functions