function [W,neighbours] = conngrads_knn(M,sigma)
%   Returns adjacency matrix for an neighbours-Nearest Neighbors 
%   similarity graph
%
%   'M' - A d-by-n matrix containing n d-dimensional data points
%   'sigma' - Parameter for Gaussian similarity function.
%
% copyright
% Guilherme Blazquez Freches 
% Donders Institute, 2017-02-06

if nargin < 2
   ME = MException('InvalidCall:NotEnoughArguments', ...
       'Function called with too few arguments');
   throw(ME);
end

n = size(M, 2);
neighbours=0;
done=false;
while done == false
    neighbours=neighbours+1;
    % Preallocate memory
    indj = zeros(1, neighbours);
    inds = zeros(1, neighbours);
    % Computes k-nearest neighbors for first node
    [idx_1,D_1] = knnsearch(M,M(1,:),'k',neighbours);
    indj=idx_1;
    inds=D_1;
    
   %Parallel Loop computing all k-nearest neighbors 
   parfor ii = 2:n
        % Computes indices and values of the neighbours
        [idx,D] = knnsearch(M,M(ii,:),'k',neighbours);
        % Save indices and value of the neighbours (appending to the
        % initial array)
        indj=[indj,idx];
        inds=[inds,D];
   end
   
   % Builds the index array (k times each index where k is the number of
   % neighbours)
   indi = zeros(1, neighbours * n);
   for jj = 1:n
   indi(1, (jj-1)*neighbours+1:jj*neighbours) = jj;
   end

    % Create sparse matrix
    W = sparse(indi, indj, inds, n, n);
    
    clear indi indj inds dist s O;
    
    
    W = max(W, W');

    % Unweighted graph
    if sigma == 0
        W = (W ~= 0);
        
        % Gaussian similarity function
    elseif isnumeric(sigma)
        W = spfun(@(W) exp(-W.^2 ./ (2*sigma^2)),W);
        
    else
        ME = MException('InvalidArgument:NotANumber', ...
            'Parameter neighbours is not numeric');
        throw(ME);
    end
    G=graph(W);
    [~,binsizes]=conncomp(G);
    if length(binsizes)==1
           done=true;
    end

end

end





