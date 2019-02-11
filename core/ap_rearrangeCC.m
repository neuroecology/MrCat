function data_ap = ap_rearrangeCC(data)
%  Affinity Propagation algorithm (Frey/Dueck, Science 2007) requires
%  asymmetric matrix data to be of the form [ seed_datapoint,
%  target_datapoint, similarity value]. This function rearranges data
%  accordingly.
% -------------------------------------------------------------------------
%
% Use:
%   rearrange_for_ap(data_matrix)
%
% Obligatory inputs:
%   data    data matrix with similarity values
%           rows    - initial datapopints
%           columns - target datapoints
%           values  - similarity measure
%
% Version history:
% 2017-06-06    suhas      created
%
% Copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2016
%--------------------------------------------------------------------------

fprintf('Rearranging data for AP clustering...\n');
[n_row, n_col] = size(data);

tic
seed_voxels     = 1:n_row;
target_voxels   = 1:n_col;

[seed_voxels, target_voxels] = meshgrid(seed_voxels, target_voxels);
% Can also be done using Matlab find - both take same time to run. 
% Do not use two for loops, though. 
seed_voxels     = reshape(seed_voxels, [numel(seed_voxels),1]);
target_voxels   = reshape(target_voxels, [numel(target_voxels),1]);
data_col        = reshape(data', [numel(data),1]);

data_ap         = [seed_voxels, target_voxels, data_col];
toc

end