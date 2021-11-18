function [ W,epsilon ] = conngrads_eps(S,epsilon)

% Returns adjacency matrix for an epsilon similarity graph
% 
% 
%
% Use
%   W = conngrads_eps(S,epsilon)
% 
%
% Obligatory inputs:
%   S          Similarity Matrix
%   epsilon    Longest distance in the graph
% Output
%   W          Sparse Graph
%  
%version history
% 2017-02-06   Guilherme Created  
%
% copyright
% Guilherme Blazquez Freches
% Donders Institute, 2017-02-06

% Preallocating memory is impossible, since we don't know how
% many non-zero elements the matrix is going to contain
indi = [];
indj = [];
inds = [];

epsilonmin=0;
epsilonmax=epsilon;
tol = 0.0001;
maxiter = 1000;
cntr = 0;
n = size(S, 2);
done=false;

while done == false
    e=(epsilonmin+epsilonmax)/2;
    for ii = 1:n  
    % Compute i-th column of distance matrix
    dist = conngrads_euc(repmat(S(:, ii), 1, n), S);
    
    % Find distances smaller than epsilon (unweighted)
    dist_max = (dist < e);
    dist_min = (dist>0);
    dist = dist_max.*dist_min;
  
    
    % Now save the indices and values for the adjacency matrix
    lastind  = size(indi, 2);
    count    = nnz(dist);
    [~, col] = find(dist);
    
    indi(1, lastind+1:lastind+count) = ii;
    indj(1, lastind+1:lastind+count) = col;
    inds(1, lastind+1:lastind+count) = S(ii,col);
    end
% Create adjacency matrix for similarity graph
W = sparse(indi, indj, inds, n, n);
G=graph(W);
[~,binsizes]=conncomp(G);
if length(binsizes)==1
    epsilonmax=e;
    if(epsilonmax-epsilonmin)<tol
        done=true;
    end
else
    epsilonmin=e;
end
cntr=cntr+1;
if cntr== maxiter
    done = true;
end
    
end

end

