function design_matrix = read_fsl_design_matrix(fname)
% function design_matrix = read_fsl_design_matrix(fname)
%
% Read an FSL .mat file from GLM into a matrix
%--------------------------------------------------------------------------
%
% Use:
%   design_matrix = read_fsl_design_matrix('model_prevspost.mat');
%
% version history
% 06022017 RBM created
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2016-02-06
%--------------------------------------------------------------------------

%===============================================
% Load the design matrix file
%===============================================

fid = fopen(fname);

% fid = fopen('/Users/rogiermars/data/social_macaquediffusion/stats/design_red_5regs_group_std.mat');
%fid = fopen('/Users/rogiermars/data/rsc/stats/model_precontrolpost.mat');

%===============================================
% Load the design lines at beginning of file
%===============================================

design_info.NumWaves = fgetl(fid); % /NumWaves
design_info.NumPoints = fgetl(fid); % /NumPoints
design_info.PPheights = fgetl(fid); % /PPheights

% Skip empty lines and /Matrix line
tline = fgetl(fid); % empty line
tline = fgetl(fid); % /Matrix line

%===============================================
% Load the matrix
%===============================================

design_matrix = [];
while ischar(tline)
    tline = fgetl(fid);
    if ischar(tline), design_matrix = [design_matrix; strread(tline)]; end
    % disp(tline)
end
design_matrix = design_matrix(:,1:end-1);

%===============================================
% Clean up
%===============================================

fclose(fid);