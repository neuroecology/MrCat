function [ dist ] = conngrads_euc( M, N )
%DISTEUCLIDEAN Calculates Euclidean distances
%   distEuclidean calculates the Euclidean distances between n
%   d-dimensional points, where M and N are d-by-n matrices, and
%   returns a 1-by-n vector dist containing those distances.
%
%
% Use
%   dist = spectral_clustering_euc(M,N)
% 
%
% Obligatory inputs:
%   M,N      same dimension vectors
% 
% Output
%   dist   Euclidean distance between vectors
% 
%version history
% 2017-02-06   Guilherme Created  
%
% copyright
% Guilherme Blazquez Freches
% Donders Institute, 2017-02-06


%==================================================
% Do the work

dist = sqrt(sum((M - N) .^ 2, 1));

end

