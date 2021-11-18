function conngrads_dconn(fname_dconn,fname_seed,hemi,varargin)
% Only works if dconn is already sliced with the right seed and target
%
% Use
%   conngrads_dconn('dconn','seed','target',3)
%
% Obligatory inputs:
%   fname_dconn                     string containing full name of the
%                                   dconn.nii file with the correct seed to
%                                   target coordinates
%   fname_seed                      string containing full name the seed
%                                   .func.gii
%   fname_target                    string containing full name of the
%                                   target .func.gii
%   nGradients                      number of gradients in the output
%   hemi                            hemisphere ('L' or 'R')
%
% Optional inputs (using parameter format):
%   outdir                          output directory (default: pwd)
%   data_level                      individual or group (default)
%   dimensionality_reduction        boolean - perform SVD on dconn
%                                   or not (default)
%   similarity_measure              metric to compute the similarity
%                                   between voxels (eta2 - default) -
%                                   measures explained in conngrads_sim.m
%   graph_construct                 method to construct the graph (epsilon
%                                   -default)methods explained in
%                                   conngrads_sp.m
%   projection_images               calculate projection images (default -
%                                   false)
%   projection_threshold            lower threshold to use in order to
%                                   present the projection images
%   laplacian_method                method to construct the laplacian
%                                   (unnormalized -default)methods explained in
%                                   conngrads_lap.m
%   surface_seed                    seeds are surfaces -default false
%   diffusion_maps                  perform diffusion maps instead of
%                                   laplasian eigenmaps
%   exclude_seed                    boolean - leave out seed indices from
%                                   your target dconn true/false (default)
%
% Output
%   none        results are reported in figures and written to the output
%               directory as gradient_g*.
%
% version history
% 2019-07-26    Suhas       ADD: option to submit individual or group data
% 2018-11-02    Suhas       ADD: option to exclude seed vertices of dconn
% 2018-11-02    Guilherme   UPDATE:added diffusion maps option 
% 2018-10-16    Suhas       FIX: rerunning analysis with larger radius
% 2018-10-04    Suhas       added hemishpere argument
%                           input func is used to make output
% 2017-02-06    Guilherme   Created
%
% copyright
% Guilherme Blazquez Freches
% Donders Institute, 2017-02-06
%--------------------------------------------------------------------------

%==================================================
% Housekeeping
%==================================================

% Defaults
outDir                      = './';
similarity_measure          = 'eta2';
dimensionality_reduction    = false;
graph_construct             = 'epsilon';
laplacian_method            = 'unnormalized';
debug_vars                  = false;
projection_images           = false;
projection_threshold        = 0; %only looking at positive correlations
diffusion_maps              = false;
exclude_seed                = true;



if nargin>3
    for vargnr = 2:2:length(varargin)
        switch varargin{vargnr-1}
            case 'outdir'
                outDir = varargin{vargnr};
            case 'similarity_measure'
                similarity_measure = varargin{vargnr};
            case 'dimensionality_reduction'
                dimensionality_reduction = varargin{vargnr};
            case 'graph_construct'
                graph_construct = varargin{vargnr};
            case 'laplacian_method'
                laplacian_method = varargin{vargnr};
            case 'debug_vars'
                debug_vars = varargin{vargnr};
            case 'projection_images'
                projection_images = varargin{vargnr};
            case 'projection_threshold'
                projection_threshold = varargin{vargnr};
            case 'diffusion_maps'
                diffusion_maps = varargin{vargnr};
            case 'exclude_seed'
                exclude_seed = varargin{vargnr};
        end
    end
end

% Create output directory
if ~isempty(outDir)
    if ~(outDir(length(outDir))=='/'), outDir = [outDir '/']; end
    if ~exist(outDir,'dir'), mkdir(outDir);
    end
end


%==================================================
% Load data
%==================================================

fprintf('Loading data...\n');

% Load datasize
M           = readimgfile(fname_dconn);
seed_ref    = readimgfile(fname_seed);
coord_seed  = find(seed_ref);

if exclude_seed
    fprintf('Excluding seed vertices from dconn...\n');
    M(:,coord_seed)   = [];
end

%==================================================
% Prepare Mirror matrix if required
%==================================================

if projection_images==true
    fprintf('Preparing mirror matrix...\n');
    [max_num_1_ratio,max_num_2_ratio,max_num_3_ratio,max_idx_1,max_idx_2,max_idx_3] = conngrads_proj_prep(M,projection_threshold); % use about 1% of your streamlines per voxel
end
fprintf('Done!\n');
%==================================================
% Perform Dimensionality reduction
%==================================================

if dimensionality_reduction == true
    fprintf('Performing dimensionality reduction...\n');
    [U,S,~] = svd(M,'econ');
    M=U*S;
end
fprintf('Done!\n');
%==================================================
% Perform between voxel similarity
%==================================================

fprintf('Performing between voxel similarity...\n');

sim_mat = conngrads_sim(M,similarity_measure);

fprintf('Done!\n');
%==================================================
% Transform into graph
%==================================================

fprintf('Transforming into a graph...\n');

[W,param]=conngrads_sp(sim_mat,graph_construct);

fprintf('Done!\n');

%==================================================
% Estimate Dimensionality
%==================================================

fprintf('Estimating dimensionality...\n');
    
nGradients=floor(conngrads_indim(sim_mat,floor(param),data_level));

fprintf('Done!\n');

%==================================================
% Compute Laplacian or Diffusion probability matrix of the graph and corresponding eigenvectors
%==================================================
if diffusion_maps==true
    fprintf('Computing Diffusion embedding and eigenvectors...\n');
    [eigenvectors,~ ] = conngrads_diff(W,nGradients+1,0);
else
    fprintf('Computing Laplacian and eigenvectors...\n');
    [eigenvectors, ~] = conngrads_lap(W,laplacian_method,nGradients+1);
    fprintf('Done!\n');
end
%==================================================
% Preparing output
%==================================================

if debug_vars==true %save debug variables if required
    filemat='/debug.mat';
    save(strcat(outDir,filemat));
end
eigenvectors = (eigenvectors(:,2:end)); % we only want the values from the second eigenvector on
for j=1:size(eigenvectors,2)
    eigenvectors(:,j) = rescale(eigenvectors(:,j),1,10);
end

gifti_data = readimgfile(fname_seed);

for k=1:nGradients
    
    outName = sprintf('%sgradient_g%d_%s.func.gii',outDir,k,graph_construct);
    gifti_data = zeros(length(gifti_data),1);
    
    for i = 1:length(eigenvectors(:,k))
        gifti_data(coord_seed(i,1))=eigenvectors(i,k);
    end
    %    saveimgfile(gifti_data,outName,side)
    create_gifti('func', outName, gifti_data, hemi); % works for for human data
    
end
end