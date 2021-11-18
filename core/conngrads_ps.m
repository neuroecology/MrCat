function [ ps ] = conngrads_ps( data )
% Creates similarity matrix from fdt_matrix2 using Pearson Correlation
%--------------------------------------------------------------------------
%
% Use
%   ps = conngrads_ps(M)
% 
%
% Obligatory inputs:
%   M       data matrix (seed voxels  * target voxels)
% 
% Output
%   ps   similarity matrix (Pearson Correlation) PAY ATTENTION TO NEGATIVE
%   VALUES
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

ps = corr(data');
clear data;


end
