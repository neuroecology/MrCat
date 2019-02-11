function C = km_init_furthest(X,k)
% Find initial positions for cluster centroids using the following method
% to make it less sensitive to initializations: pick a random point an
% call it the first cluster centroid, then the second cluster centroid is
% the point furthest from the first one, the third centroid is the point
% furthest from the average of previous, etc. until you have k centroids.
%--------------------------------------------------------------------------
%
% Use
%   C = km_init_furthest(X,k)
%
% Input
%   X       variables * dimensions data matrix
%   k       number of clusters
%
% Output
%   C       k * dimensions matrix of centroids
%
% version history
% 2015-09-16	Lennart		documentation
% 2015-09-01  Rogier    Prepared for GitHub
% 2014-11-29  Lennart   rewrote algorithm for speed
% 2013-07-01  Rogier    created
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2013-07-01
%--------------------------------------------------------------------------


%===============================
%% pick initial centroids
%===============================

ndims = size(X,2);

% First centroid, based on mean of each dimension
C = nan(k,ndims);
C(1,:) = rand(1,ndims).*mean(X,1);

% Other centroids
for c = 2:k

    % Calculate distance of each point to mean of the current ctrs
    ctr_means = mean(C(1:c-1,:),1);
    [~,idx] = max(euclid(X,ctr_means));

    % Find max distance and make that the new centroid distances
    C(c,:) = X(idx,:);

end

%% legacy debugging
% figure;
% plot(X(:,1),X(:,2),'r.','MarkerSize',12)
% hold on
% plot(C(:,1),C(:,2),'kx','MarkerSize',12,'LineWidth',2)
% plot(C(:,1),C(:,2),'ko','MarkerSize',12,'LineWidth',2)
% legend('Cluster 1','Cluster 2','Centroids','Location','NW');
% hold off;
