function C = kmeans_init_kdtree(X,k)
% Find appropriate initial centroids for kmeans clustering based on a quick
% kd-tree clustering of the data. Following Redmond et al. "A method for
% initialising the k-means clustering algorithm using kd-trees",
% PattRecogLett, 2007
%--------------------------------------------------------------------------
%
% Use
%   C = kmeans_init_kdtree(X,k)
%
% Input
%   X       points-by-dimension matrix with multivariate data
%   k       scalar with number of clusters to initialize
%
% Output
%   C       k-by-size(X,2) matrix with the initial centroids corresponding
%           to each class
%
% version history
% 2015-09-16	Lennart		documentation
% 2014-11-30  Lennart   created
%
% Reference
%   Redmond; Heneghan - 2007 - PattRecogLett - A method for initialising
%   the k-means clustering algorithm using kd-trees
%
% copyright
% Lennart Verhagen & Rogier B. Mars
% University of Oxford & Donders Institute, 2014-11-30
%--------------------------------------------------------------------------

%===============================
%% build kd-tree
%===============================

% determine maximum number of samples in a leaf
[n,d] = size(X);
n_max = n/(10*k);

% set density ranking and scaling
flg_rank = true;
flg_sqrt = true;

% build tree
tree = kdtree_build(X,n_max);

% throw away leafs with outliers (20% lowest densities)
[~,idx] = sort([tree(:).density],'ascend');
n_leaf = length(idx);
n_cut = round(n_leaf/5);

% rank code and scale the densities if requested
if flg_rank
    dens = (1:n_leaf-n_cut)';
else
    dens = vertcat(tree(idx(n_cut+1:n_leaf)).density);
end
if flg_sqrt
    dens = sqrt(dens);
end

% retrieve centroids
centroids = vertcat(tree(idx(n_cut+1:n_leaf)).centroid);
n_sel = n_leaf-n_cut;


%===============================
%% pick initial centroids
%===============================

% pick first initial centroid
C = nan(k,d);
C(1,:) = centroids(end,:);

% pick following centroids
for i = 2:k
    % calculate distance of leaf buckets to selected centroids
    dist = nan(n_sel,(i-1));
    for j = 1:(i-1)
        dist(:,j) = euclid(centroids,C(j,:),2);
    end
    % weight by density rank
    distdens = min(dist,[],2) .* dens;
    [~,idx_max] = max(distdens);
    C(i,:) = centroids(idx_max,:);
end


%===============================
%% sub functions
%===============================

function tree = kdtree_build(X,n_max,tree)
% build a kd-tree

% initialize tree
if nargin < 3 || isempty(tree)
    tree = struct('X',{},'centroid',{},'density',{});
end
n_leaf = length(tree);

% get dimension range
r = max(X,[],1) - min(X,[],1);

% determine if a leaf has been reached
n = size(X,1);
if n <= n_max
    l = n_leaf+1;
    tree(l).X = X;
    tree(l).centroid = mean(X,1);
    % prevent negative and infinite densities
    if all(r>0)
        tree(l).density = n/prod(r);
    elseif all(r<=0)
        tree(l).density = 0;
    else
        r(r<=0) = mean(r(r>0));
        tree(l).density = n/prod(r);
    end
    return
end

% find dimension with biggest range
[~,dim] = max(r);
% median split along dim
med = median(X(:,dim));
left = X(X(:,dim)<=med,:);
right = X(X(:,dim)>med,:);
% and recursively re-iterate algorithm
tree = kdtree_build(left,n_max,tree);
if ~isempty(right)
    tree = kdtree_build(right,n_max,tree);
end
