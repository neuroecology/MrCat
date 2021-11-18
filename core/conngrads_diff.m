function [ maps,eigenvals ] = conngrads_diff(W,k,t)
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
%   method     method to compute the Laplacian     
%               Choices are:
%              'unnormalized' - Unnormalized
%               'shimlk' - Normalized according to Shi and Malik (2000)
%               'jorwei' - Normalized according to Jordan and Weiss (2002)
%  
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
% avoid dividing by zero
degs(degs == 0) = eps;
% calculate D^(-1/2)
D = spdiags(1./(degs.^0.5), 0, size(D, 1), size(D, 2));
% calculate normalized Laplacian
L_alfa = D * W * D;
degs_alfa =sum(L_alfa,2);
degs_alfa(degs_alfa == 0) = eps;
D_alfa  = sparse(1:size(L_alfa, 1), 1:size(L_alfa, 2), degs_alfa);
D_alfa= spdiags(1./(degs_alfa.^1), 0, size(D_alfa, 1), size(D_alfa, 2));
P=D_alfa*L_alfa;
%compute the eigenvectors corresponding to the k smallest
% eigenvalues
[maps, eigenvals] = eigs(P,k,'largestabs');
eigenvals = diag(eigenvals);
if t==0
    eigenvals(2:end)=(eigenvals(2:end)./(1-eigenvals(2:end)));
else
    eigenvals(2:end)=eigenvals(2:end).^t;
end
for j=2:size(maps,2)
    maps(:,j)=maps(:,j)./maps(:,1);
end
for j=1:size(maps,2)
    maps(:,j)=eigenvals(j)*maps(:,j);
end
end