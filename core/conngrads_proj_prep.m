function [max_num_1_ratio,max_num_2_ratio,max_num_3_ratio,max_idx_1,max_idx_2,max_idx_3] = conngrads_proj_prep(M_proj,threshold)
%
% Computes ratios needed to compute projection images (the ratios
% will then weight the contribution of each seed voxel to each target
% voxel)
%
% Use
%   [max_num_1_ratio,max_num_2_ratio,max_num_3_ratio,max_idx_1,max_idx_2,max_idx_3] = conngrads_proj_prep(M,100);
% 
%
% Obligatory inputs:
%   M_proj       data matrix (seed voxels  * target voxels)
% 
%   threshold    threshold for data matrix (100 seems to be an empirical
%                good one for 5k-10k streamlines per voxel)
%
% Output
%   max_num_1_ratio,max_num_2_ratio,max_num_3_ratio,max_idx_1,max_idx_2,max_idx_3
%   indexes and ratio they correspond to.
% 
%version history
% 2017-02-06   Guilherme Created  
%
% copyright
% Guilherme Blazquez Freches
% Donders Institute, 2017-02-06

M_proj(M_proj < threshold)=0; % apply threshold
max_num_1 = zeros(1,size(M_proj,2));
max_num_2 = zeros(1,size(M_proj,2));
max_num_3 = zeros(1,size(M_proj,2));

max_num_1_ratio = zeros(1,size(M_proj,2));
max_num_2_ratio = zeros(1,size(M_proj,2));
max_num_3_ratio = zeros(1,size(M_proj,2));

max_idx_1 = zeros(1,size(M_proj,2));
max_idx_2 = zeros(1,size(M_proj,2));
max_idx_3 = zeros(1,size(M_proj,2));


[B,I]=sort(M_proj,1,'descend'); % get highest projections
    
max_num_1=B(1,:);
max_num_2=B(2,:);
max_num_3=B(3,:);
max_idx_1=I(1,:);
max_idx_2=I(2,:);
max_idx_3=I(3,:);

for i=1:size(M_proj,2)
    aux = sum([max_num_1(i),max_num_2(i),max_num_3(i)])+0.01;
    max_num_1_ratio(i)= max_num_1(i)/aux;
    max_num_2_ratio(i)= max_num_2(i)/aux;
    max_num_3_ratio(i)= max_num_3(i)/aux;
end

end

