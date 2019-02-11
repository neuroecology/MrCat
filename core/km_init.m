function Cinit = km_init(X,k,method,varargin)
% set initial starting points (seeds) for k-means clustering
%--------------------------------------------------------------------------
%
% Use
%   C = km_init(X,k,method)
%   C = km_init(X,k,method,n_repeats)
%
% Obligatory inputs:
%   X       data matrix to cluster (variables * dimensions)
%   k       number of desired clusters
%   method  initialisation method, pick from one of the following:
%       random          simply draw seeds from the data at random
%       plus, plusplus  select pseudo-random seeds from the data following
%                       D. Arthur and S. Vassilvitskii, "k-means++: The
%                       Advantages of Careful Seeding", Technical Report
%                       2006-13, Stanford InfoLab, 2006.
%       furthest, kkz   select a random seed and place subsequent seeds as
%                       far away from previous as possible
%       kdtree          place initial seeds on the kd-tree following
%                       Redmond et al. "A method for initialising the
%                       k-means clustering algorithm using kd-trees",
%                       PattRecogLett, 2007
%
% Opional input:
%   n_repeats  number of repeats (default 1)
%
% Output
%   Cinit   initial seed centroids (k * dimensions as in X)
%
% version history
% 2015-10-15 Rogier     Added repeat option
% 2015-09-16	Lennart		documentation
% 2015-09-01  Rogier    Prepared for github
% 2015-02-01  Lennart   created
%
% copyright of kmeans++ ('plusplus') initialisation code (see below)
%   origianl file name: kmeans.m
%   Version: 2013-02-08
%   Written by Laurent Sorber (Laurent.Sorber@cs.kuleuven.be)
%
% copyright
% Lennart Verhagen & Rogier B. Mars
% University of Oxford & Donders Institute, 2015-02-01
%--------------------------------------------------------------------------


%===============================
%% housekeeping
%===============================

% sort input
if nargin < 3 || isempty(method), method = 'plusplus'; end
if nargin<4, n_repeats = 1; elseif nargin==4, n_repeats = varargin{1}; end


%===============================
%% pick initial k-means centroids
%===============================

for r = 1:n_repeats
    
    % switch between centroid initialisation algorithms
    switch lower(method)
        
        case 'random'
            p = randperm(size(X,1));
            Cinit(:,:,r) = X(p(1:5),:);
            
        case {'plus','plusplus'}
            % The k-means++ algorithm
            % D. Arthur and S. Vassilvitskii, "k-means++: The Advantages of
            % Careful Seeding", Technical Report 2006-13, Stanford InfoLab,
            % 2006.
            n = size(X,1);
            C = X(1+round(rand*(n-1)),:);
            idx = ones(n,1);
            for i = 2:k
                D = X-C(idx,:);
                D = cumsum(sqrt(dot(D,D,2)));
                if D(end) == 0
                    C(i:k,:) = X(ones(k-i+1,1),:);
                else
                    C(i,:) = X(find(rand < D/D(end),1),:);
                    if i<k
                        [~,idx] = max(bsxfun(@minus,2*real(X*C'),dot(C,C,2).'),[],2);
                    end
                end
            end
            Cinit(:,:,r) = C;
            
        case {'furthest','kkz'}
            % run km_init_furthest to place initial centres as far out as possible
            Cinit(:,:,r) = km_init_furthest(X,k);
            
        case 'kdtree'
            % run kmeans_init_kdtree to place initial centroids on the kd-tree
            % Redmond; Heneghan - 2007 - PattRecogLett - A method for
            % initialising the k-means clustering algorithm using kd-trees
            warning('KMEANS_INIT:kdtree_replications','The kdtree initialisation algorithm will give the same result for every replication.');
            Cinit(:,:,r) = km_init_kdtree(X,k);
            
        otherwise
            error('Error in MrCat:KMEANS_INIT:unsupported_method','This method (%s) is not currently supported.',method);
            
    end % switch lower(method)
    
end % r
%--------------------------------------------------------------------------


%% Copyright notice for k-means++ ('plusplus') initialisation
%--------------------------------------------------------------------------
% Copyright (c) 2013, Laurent Sorber
% All rights reserved.
%
% Redistribution and use in source and binary forms, with or without
% modification, are permitted provided that the following conditions are
% met:
%
%     * Redistributions of source code must retain the above copyright
%       notice, this list of conditions and the following disclaimer.
%     * Redistributions in binary form must reproduce the above copyright
%       notice, this list of conditions and the following disclaimer in the
%       documentation and/or other materials provided with the distribution
%
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
% IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
% THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
% PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
% CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
% EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
% PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
% PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
% LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
% NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
% SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
