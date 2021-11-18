function [ cc ] = conngrads_cc( data )
% Creates similarity matrix from fdt_matrix2 using cc'
%--------------------------------------------------------------------------
%
% Use
%   cc = conngrads_cc(M)
% 
%
% Obligatory inputs:
%   M       data matrix (seed voxels  * target voxels)
% 
% Output
%   cc   similarity matrix (matrix * transposed matrix)
% 
%version history
% 2017-02-06   Guilherme Created  
%
% copyright
% Guilherme Blazquez Freches
% Donders Institute, 2017-02-06


%==================================================
% Do the work
%==================================================

cc = data*data';
clear data;


end

