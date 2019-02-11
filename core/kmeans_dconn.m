  function kmeans_dconn(data_dconn_file, mask_func_file, number_of_clusters, hemi, varargin)
% Wrapper to run simple kmeans clustering on dense connectome
% (filename.dconn.nii) files. Runs standard matlab kmeans, writes
% results to disk as results_filename.func.nii files.
% -------------------------------------------------------------------------
% Note: Results are stored in the folder from where this function is called
% -------------------------------------------------------------------------
%
% Use:
%   dconn_kmeans('your_data.dconn.nii','your_mask.func.nii', [vec_of_clusters], 'hemisphere_data')
%
% Obligatory inputs:
%   data_dconn_file         string containing full name of the dconn file
%   mask_func_file          string containing full name of the mask to be used
%   number_of_clusters      vector with number of clusters to use
%   hemi                    define which hwmisphere to work on 'L' or 'R'
%
% Optional inputs (using parameter format):
%   n_repeats               number of kmeans replications per cluster
%                           number (default 20)
%   cluster_this            determines what should be clustered (default data)
%   outdir                  output directory
%                           (default: pwd/dconn_km_clusters)
%   quick_plot              specify if quick reference plot need to be
%                           produced
%   backproject             backproject solution clusters? 'true'/'false'
%                           (default true)
%
% Output:
%   none        results are reported in figures and written to the output
%               directory as clusters_*.
%
% Version history:
% 2016-07-11    suhas - update: option to cluster on data, CC, CC+D, PCA
%                               backprojection - option    
% 2016-05-11    suhas - update: species independent, option of
%                       MrCat-kmeans, prints a summary text file
% 2016-04-20    suhas - created
%
% Issues:
% 1. Fix quick plots for batch jobs
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2015-10-14
%--------------------------------------------------------------------------
%==================================================
% Housekeeping
%==================================================
clc
diary('dconn_kmeans.txt'); diary on

% Set defaults
cluster_this     = 'data';
n_repeats        = 20;
outdir           = [pwd filesep 'dconn_km_clusters' filesep];
species          = 'macaque';
Cinit_method     = 'plusplus';
ncomp            = 100;
backproject_flag = true;
plot_flag        = false;

if nargin>4
    for vargnr = 2:2:length(varargin)
        switch varargin{vargnr-1}
            case 'n_repeats'
                n_repeats = varargin{vargnr};
            case 'cluster_this'
                cluster_this = varargin{vargnr};
            case 'Cinit_method'
                Cinit_method = varargin{vargnr};
            case 'outdir'
                outdir = [pwd filesep varargin{vargnr}];
            case 'species'
                species = varargin{vargnr};
            case 'pca_ncomp'
                ncomp = str2double(varargin{vargnr});
                pca_flag = true;
            case 'backproject'                
                if strcmp(varargin{vargnr}, 'false')
                    backproject_flag = false;
                end                
        end
    end
end

% Create output directory if doesn't exist
if ~exist(outdir,'dir'), mkdir(outdir); end;

% Check if hemishpere is specified
if isempty(hemi), error('Define hemisphere. Valid input: L, R'); end;

% Make necessary path variables - will be useful to make a master function
% for the purpose of defining
switch lower(species)
    case 'macaque'
        fprintf('Fetching path to %s %s surf file ...\n', species, hemi);
        if lower(hemi)=='l'
            surf_path = '~/code/MrCat-dev/surfops/macaque_10k_surf/lh.inflated.10k.surf.gii';
        elseif lower(hemi)=='r'
            surf_path = '~/code/MrCat-dev/surfops/macaque_10k_surf/rh.inflated.10k.surf.gii';
        end
    case 'human'
        fprintf('Fetching path to %s %s surf file ...\n', species, hemi);
        if lower(hemi)=='l'
            surf_path = '~/code/MrCat-dev/surfops/CIFTIMatlabReaderWriter_old/L.surf.gii';
        elseif lower(hemi)=='r'
            surf_path = '~/code/MrCat-dev/surfops/CIFTIMatlabReaderWriter_old/R.surf.gii';
        end
end

roi_path = [pwd filesep mask_func_file];

%==================================================
% Load data
%==================================================
fprintf('Loading data... \n');
% Load data
[~,~,ext] = fileparts(data_dconn_file);
if isequal(ext,'.nii')
    dconn = ciftiopen(data_dconn_file);
else
    error('Not a dconn file. Please check.')
end

% Clean-up dconn file
fprintf('Removing -Inf values from dconn file before clustering. \n');

dconn.cdata = dconn.cdata+1;
dconn.cdata(dconn.cdata==-Inf) = 0;

fprintf('done \n');

%==================================================
% Perform kmeans
%==================================================
% Determine what data to use for clustering
switch lower(cluster_this)
    case 'data'
        fprintf('Proceeding to cluster on data \n');
        % Cluster based on data alone
        CC = dconn.cdata;
    case 'cc'
        fprintf('Proceeding to cluster on CC matirx \n');
        % Calculate cross-correlation matrix
        CC = km_calculateCC(dconn.cdata', 'plot_data', 'no'); % transpose to make CC of seed mask.
    case 'd'
        fprintf('Proceeding to cluster on CC+D \n');
        % First calculate cross-correlation matrix
        CC = km_calculateCC(dconn.cdata', 'plot_data', 'no');
        % Calculate geodesic distances - inflated surf file
        tic
        CC = km_calculateD(CC, roi_path, surf_path); % - Use this line for default settings
        % CC = km_calculateD(CC, roi_path, surf_path, 'fudge_factor', '0.99', 'dist_method','geodesic');
        toc
    case 'pca'
        fprintf('Proceeding to cluster on PCA \n');
        fprintf('Running PCA with %d components. \n', ncomp);
        [~,comp] = pca(dconn.cdata,'NumComponents', ncomp);
        CC = comp;
    otherwise
        error('Error: check variable cluster_on')
end

fprintf('Performing kmeans... \n');

kmeans_solutions = [];
for c = number_of_clusters

    fprintf('...%i clusters \n', c);

    idx = kmeans(CC, c, 'replicates', n_repeats); % Perform kmeans using standard matlab kmeans

    %Cinit = km_init(CC,c,Cinit_method,n_repeats); % Determine kmeans starting values
    %idx = kmeans_fast(CC,c,'replicates',n_repeats,'Cinit',Cinit); % Perform kmeans

    %--------------------------------------------
    % Collect results
    %--------------------------------------------
    kmeans_solutions = [kmeans_solutions idx]; % store the result

    % Reorder the cross-correlation matrix and save it to disk
%    sortedCC = sort_CC_matrix(CC,idx,idx,2,['sorted_matrix_' num2str(c) '_clusters']);

    %--------------------------------------------
    % Backproject to brain
    %--------------------------------------------
    if backproject_flag
        
        fprintf('Backprojecting to brain... \n')    
        mask = gifti(mask_func_file);

        %original_ind = find(mask.private.data{1}.data==1); - % Doesn't work!
        % only hand-drawn border-->func has 1's.
        original_ind = find(mask.private.data{1}.data);
        num_clusters = unique(idx);
        for i_ind = 1:length(num_clusters)
            new_ind = idx==num_clusters(i_ind);
            mask.private.data{1}.data(original_ind(new_ind)) = num_clusters(i_ind); % replace data of indentified indices with their respective cluster number
        end

        switch lower(species)
            case 'macaque'
                create_primate_func_gii(mask.cdata,[outdir 'dconn_clusters_' num2str(c)], upper(hemi));
            case 'human'
                create_func_gii(mask.cdata,[outdir 'dconn_clusters_' num2str(c)], upper(hemi));
        end
        
    end
    % Make a quick reference image
    % does not work for a batch job on the cluster yet. Hence off by default
    if plot_flag
        data_to_plot = [outdir 'dconn_clusters_' num2str(c) '.func.gii'];
        figure_name  = ['dconn_clusters_' num2str(c) '.png']; % needs extension
        quick_plot(data_to_plot, upper(hemi), figure_name)
    end

end

close all
save dconn_kmeans_all
fprintf('Finished running dconn_kmeans. \n');
diary off
end
