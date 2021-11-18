function conngrads_fdt(fname_fdt_matrix2,fname_fdt_paths,fname_coords_for_fdt_matrix2,fname_tract_space_coords_for_fdt_matrix2,hemi,varargin)
 
%Wrapper to run conngrads on the output of FSL's probtrackx
% ran with --omatrix2 option. 
%
% Use
%   conngrads_fdt('fdt_matrix2.dot','fdt_paths.nii.gz','coords_for_fdt_matrix2','tract_space_coords_for_fdt_matrix2',3)
%   conngrads_fdt('./mydatadir/fdt_matrix2.dot','./mydatadir/fdt_paths.nii.gz','./mydatadir/coords_for_fdt_matrix2','/mydatadir/tract_space_coords_for_fdt_matrix2',3,'outdir','./myanalysisdir')
%
% Obligatory inputs:
%   fname_fdt_matrix2               string containing full name of the
%                                   fdt_matrix2 file from FSL
%   fname_fdt_paths                 string containing full name of
%                                   fdt_paths file from FSL
%   fname_coords_for_fdt_matrix2    string containing full name of the
%                                   coords_for_fdt_matrix2_file from FSL
%   tract_space_coords_for_fdt_matrix2    string containing full name of the
%                                   tract_space coords_for_fdt_matrix2_file from FSL
%   hemi                            hemisphere ('L' or 'R')
%
% Optional inputs (using parameter format):
%   outdir                          output directory (default: pwd)
%   dimensionality_reduction        boolean - perform SVD on fdt_matrix2
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
%
%   surface_seed                    seeds are surfaces -default false
%   diffusion_maps                  do diffusion maps instead of LE -
%                                   default false
%   vertices                      number of vertices in the output file 
%                                   default 32492
%  
%   
%
% Output
%   none        results are reported in figures and written to the output
%               directory as gradient_g*.
% version history
% 2017-02-06   Guilherme Created  
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
data_level                  = 'individual';
similarity_measure          = 'eta2';
dimensionality_reduction    = false;
graph_construct             = 'epsilon';
debug_vars                  = false;
projection_images           = false;
projection_threshold        = 100; % default for 10k streamlines
surface_seed                = false;
diffusion_maps              = false;
vertices                    = 32492; %default for humans but may be t


if nargin>5
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
      case 'debug_vars'
        debug_vars = varargin{vargnr};
      case 'projection_images'
        projection_images = varargin{vargnr};
      case 'projection_threshold'
        projection_threshold = varargin{vargnr};
      case 'surface_seed'
        surface_seed = varargin{vargnr};
      case 'diffusion_maps'
        diffusion_maps = varargin{vargnr};
      case 'vertices'
        vertices = varargin{vargnr};
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

fprintf('Loading data...');

% Load datasize
[~,~,ext] = fileparts(fname_fdt_matrix2);
if isequal(ext,'.dot')
  x = load(fname_fdt_matrix2);
  M=full(spconvert(x)); % Reorder the data
elseif isequal(ext,'.gz')
  M = read_avw(fname_fdt_matrix2);
end

% use the FieldTrip image reader/writer package
refImg = ft_read_mri(fname_fdt_paths);
zeroImg = 0*refImg.anatomy;

% temporary place holder for the output image(s)
outImg = zeroImg;
if projection_images==true
    outImg_pro = zeroImg;
end

% load the reference image - gradients
[~,~,ext] = fileparts(fname_coords_for_fdt_matrix2);
if isempty(ext)
  coord = load(fname_coords_for_fdt_matrix2)+1;
elseif (isequal(ext,'.gz') || isequal(ext,'.nii'))
    coord = ft_read_mri(fname_coords_for_fdt_matrix2);
    coord = coord.anatomy+1;
end

if projection_images==true   
% load the reference image - projections
[~,~,ext] = fileparts(fname_tract_space_coords_for_fdt_matrix2);
    if isempty(ext)
  coord_pro = load(fname_tract_space_coords_for_fdt_matrix2)+1;
    elseif (isequal(ext,'.gz') || isequal(ext,'.nii'))
    coord_pro = ft_read_mri(fname_tract_space_coords_for_fdt_matrix2);
    coord_pro = coord_mri.anatomy+1;
    end
end

fprintf('done\n');
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
    
[nGradients,~] = MLE(M);% Requires the use of an external toolbox 'https://www.mathworks.com/matlabcentral/fileexchange/40112-intrinsic-dimensionality-estimation-techniques'

fprintf('Done!\n');

%==================================================
% Compute Laplacian or Diffusion probability matrix of the graph and corresponding eigenvectors
%==================================================
if diffusion_maps==true
    fprintf('Computing Diffusion embedding and eigenvectors...\n');
    [eigenvectors,~ ] = conngrads_diff(W,floor(nGradients)+1);
    rads_diff(W,nGradients+1,0);
else
fprintf('Computing Laplacian and eigenvectors...\n');
[eigenvectors, ~] = conngrads_lap(W,floor(nGradients)+1);
fprintf('Done!\n');
end
%==================================================
% Output preparation
%==================================================

if debug_vars==true %save debug variables if required
    filemat='/debug.mat';
    save(strcat(outDir,filemat));
end

eigenvectors = (eigenvectors(:,2:end)); % we only want the values from the second eigenvector on 
for j=1:size(eigenvectors,2)
    eigenvectors(:,j) = rescale(eigenvectors(:,j),1,10);
end

    if projection_images==true
        for n=1:nGradients
            fprintf('Computing projection images... \n');
            projection_vec=zeros(1,length(max_idx_1));
            gradient_values = eigenvectors(:,n);
            for i=1:length(max_idx_1)
            projection_vec(i)=(gradient_values(max_idx_1(i))*max_num_1_ratio(i))+(gradient_values(max_idx_2(i))*max_num_2_ratio(i))+(gradient_values(max_idx_3(i))*max_num_3_ratio(i)); %scaled contribution of top 3 connected voxels
            end
        ind_target = sub2ind(size(outImg),coord_pro(:,1),coord_pro(:,2),coord_pro(:,3));
        clusterImg = outImg_pro;
        clusterImg(ind_target) = projection_vec;

  % write the cluster mask image to the output directory
        outName = sprintf('%sprojection_g%d_%s.nii.gz',outDir,n,graph_construct);
        ft_write_mri(outName,clusterImg,'dataformat','nifti','transform',refImg.transform);
        end
    end

    if surface_seed==true
        for k=1:nGradients
            outName = sprintf('%sgradient_g%d_%s.func.gii',outDir,k,graph_construct);
            gifti_data=zeros(vertices,1); %32kres
            for i = 1:length(eigenvectors(:,k))
                gifti_data(coord(i,5))=eigenvectors(i,k);
            end
        saveimgfile(gifti_data,outName,hemi)
        end
    else 
    for k=1:nGradients
 % create a mask of cluster indices
        ind = sub2ind(size(outImg),coord(:,1),coord(:,2),coord(:,3));
        j = eigenvectors(:,k);
        clusterImg = zeroImg;
        clusterImg(ind) = j;

  % write the cluster mask image to the output directory
        outName = sprintf('%sgradient_g%d_%s.nii.gz',outDir,k,graph_construct);
        ft_write_mri(outName,clusterImg,'dataformat','nifti','transform',refImg.transform);


fprintf('Done!\n');
    end
    end
end



