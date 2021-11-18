function [ W,param ] = conngrads_sp(S,method)
% Creates sparse (or fully connected) graph with from the similarity matrix by finding the ideal
% given the method chosen
% 
%
% Use
%   W = conngrads_sp(S,method)
% 
%
% Obligatory inputs:
%   S       similarity matrix (seed voxels)
%   method  method to compute the adjacency graph ( 'full' - full similarity
%   graph  'knn' - k nearest neighbors or 'epsilon' for neighborhood-based metric)
%   
%
%
%
% 
% Output
%   W   Sparse Graph (or fully connected) adjacency matrix
%   epsilon Measure of distance both used for knn and epsilon ball 
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

G=graph(S); %%transforms the similarity matrix into a Matlab graph
t=minspantree(G); %Gets one minimal spanning tree from the graph (useful to
                 %calculate other variables)

% Getting the ideal epsilon according to von Luxburg corresponds to using the maximal distance in the minimum spanning tree of the graph
[~,max_pos] = max(t.Edges.Weight);                  
nodes_max_pos = [t.Edges.EndNodes(max_pos,1),t.Edges.EndNodes(max_pos,2)];
distance_vector = conngrads_euc(repmat(S(:, nodes_max_pos(1)), 1, length(S)),S);
epsilon = distance_vector(nodes_max_pos(2));

switch method
    case 'epsilon'
        [W,param]=conngrads_eps(S,epsilon);
    case 'knn'
        [W,param]=conngrads_knn(S,epsilon);
    case 'full'
        W=conngrads_gau(S,epsilon);
end
    