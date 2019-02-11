function ap_cluster_dconn(data_dconn_file, mask_func_file, hemi, varargin)
% Wrapper to run affinity propagation (AP) clustering on dense connectome
% (filename.dconn.nii) files. Runs standard AP algorithm, based on 
% (Frey/Dueck, Science 2007), writes results to disk as 
% results_filename.func.nii files.
% -------------------------------------------------------------------------
% Note: Results are stored in the folder from where this function is called
% -------------------------------------------------------------------------
%
% Use:
%   ap_cluster_dconn('your_data.dconn.nii','your_mask.func.nii','hemisphere')
%
% Obligatory inputs:
%   data_dconn_file     string containing full name of the dconn file
%   mask_func_file      string containing full name of the mask to be used
%   hemi                define which hemisphere to work on 'L' or 'R'
%   preference          submit a scalar, if you want to make it equally 
%                       likely for all data points to be exemplars
%                       If S is a vector of your similarity matrix values, 
%                   >>  DEFAULT: min(S) - (max(S) - min(S))
%   ap_cluster_dconn('your_data.dconn.nii','your_mask.func.nii','hemisphere','preference','your_preference_vector')
%
% Version history
% suhas     2017-07-27  comments, check symmetry of data_CC
% suhas     2017-02-16  created
%
% Copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2017
%--------------------------------------------------------------------------

% add toolboxes
clc;
addpath(genpath('~/code/MrCat-dev'));

diary('ap_clustring_on_dconn.txt'); diary on

% Read data
fprintf('Reading data...\n');
data = readimgfile(data_dconn_file);

% Calculate cross-correlation matrix of the seed-region
fprintf('Calculating similarity measure (correlation)...\n');
data_CC = ap_calculateCC(data'); clear data;

% If similarity measure is an asymmetric matrix, rearrange it for AP
% and set preference value to min(S) - (max(S) - min(S))
if issymmetric(data_CC)
    data_CC_ap = data_CC; clear data_CC;
    preference = min(min(data_CC_ap))-((max(max(data_CC_ap))-min(min(data_CC_ap))));
else
    data_CC_ap = ap_rearrangeCC(data_CC); clear data_CC;
    preference = min(data_CC_ap(:,3))-(max(data_CC_ap(:,3))-min(data_CC_ap(:,3)));
end

% If preference value is given, use that instead.
if nargin>3
    for vargnr = 2:2:length(varargin)
        switch varargin{vargnr-1}
            case 'preference'
                clear preference
                preference = varargin{vargnr};           
        end
    end
end

% Submit to AP clustering algorithm
fprintf('Running AP culstering algorithm...\n');
[idx,~,~,~] = apcluster(data_CC_ap, preference, 'plot','nonoise');

% idx is array of values of exemplars (clusters centres). Replacing idx
% with continuous numbers, starting from 1
cluster_centres = unique(idx);
for i = 1:length(cluster_centres)
    replace_ind         = find(idx==cluster_centres(i));
    idx(replace_ind)    = i;
end 

% Get mask file and replace data with cluster solutions
mask         = gifti(mask_func_file);
original_ind = find(mask.private.data{1}.data);

fprintf('Compiling results to make a func.gii file...\n');
clusters = unique(idx); 
for i_ind = 1:length(clusters)
    new_ind = find(idx==clusters(i_ind));     
    % replace data of indentified indices with their respective cluster number    
    mask.private.data{1}.data(original_ind(new_ind)) = clusters(i_ind); 
end

% Backproject solution to a func file
fprintf('Backprojecting...\n');
saveimgfile(mask.cdata, ['ap_solution_' num2str(length(clusters)) '.func.gii'], hemi); % for macaque

save ap_cluster_all_var

fprintf('Fin.\n');

diary off
end
