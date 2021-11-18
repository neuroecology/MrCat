function [W] = conngrads_gau( M,sigma )
%Returns full similarity graph
%   Returns adjacency matrix for a full similarity graph where
%   a Gaussian similarity function with parameter sigma is
%   applied.
%
%   'M' - A d-by-n matrix containing n d-dimensional data points
%   (similarity matrix)
%   'sigma' - Parameter for Gaussian similarity function
%
%version history
% 2017-02-06   Guilherme Created  
%
% copyright
% Guilherme Blazquez Freches
% Donders Institute, 2017-02-06

% Compute distance matrix
W = squareform(pdist(M'));

% Apply Gaussian similarity function
W = exp(-W.^2 ./ (2*sigma^2));



end

