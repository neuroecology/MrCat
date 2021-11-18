function [ maps,eigenvals ] = conngrads_lap(W,k)
% Returns the eigenvectors of the Laplacian matrix of the given graph,
% using the algorithm specified in method.
%
%
% Use
%   maps = conngrads_lap(G,'unnormalized')
%
%
% Obligatory inputs:
%   W          Sparse Graph (adjacency matrix)
%   k           number of gradients
% Output
% maps          eigenvectors of the laplacian corresponding to the
%               connectivity gradient maps
% eigenvals     corresponding eigenvalues
%
%version history
% 2017-02-06   Guilherme Created
%
% copyright
% Guilherme Blazquez Freches
% Donders Institute, 2017-02-06

% calculate degree matrix
degs = sum(W, 2);
D    = sparse(1:size(W, 1), 1:size(W, 2), degs);

% compute unnormalized Laplacian
L = D - W;

% compute the eigenvectors corresponding to the k smallest
% eigenvalues
[maps, eigenvals] = eigs(L,D,k,'smallestabs');
end
