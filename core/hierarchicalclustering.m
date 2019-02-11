function hierarchicalclustering(data,varargin)
% function hierarchicalclustering(data,varargin)
%
% Perform hierarchical clustering analysis using Matlab's linkage function
%--------------------------------------------------------------------------
%
% Use
%   hierarchicalclustering(group);
%   hierarchicalclustering(group,'toplot','yes');
%
% Obligatory inputs:
%   data    voxels*variables data matrix
%
% Optional inputs:
%   'distmeasure'   'Euclidean' (default) or any from pdist
%   'toplot'        Plot hierarchy 'yes' or 'no' (default)
%   'labels'        cell array of cluster labels for plotting
%   'P'             number of leaf nodes to display (default 30, set 0 for
%                   complete tree)
%
% Output:
%   none    results are reported in figure form
%
% version history
% 14042016 RBM MrCat compatible
% 13102014 RBM Fixed some bugs and added labels and P options
% 04032014 RBM Created
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2016-04-14
%--------------------------------------------------------------------------

%=========================================================
% Housekeeping
%=========================================================

% Defaults
distmeasure = 'Euclidean';
toplot = 0;
labels = [];
P = 30;

if nargin>2
    for argnr = 3:2:nargin
        switch varargin{argnr-2}
            case 'distmeasure'
                distmeasure = varargin{argnr-1};
            case 'toplot'
                if isequal(varargin{argnr-1},'no'), toplot=0;
                elseif isequal(varargin{argnr-1},'yes'), toplot=1;
                end
            case 'labels'
                labels = varargin{argnr-1};
            case 'P'
                P = varargin{argnr-1};
        end
    end
end

%=========================================================
% Do the work
%=========================================================

% Calculate distance
% pdist(X) returns a vector D containing the Euclidean distances
% between each pair of observations in the M-by-N data matrix X. Rows of
% X correspond to observations, columns correspond to variables.
D = pdist(data,distmeasure);

% Linkage
Z = linkage(D);

% Plot
if toplot==1
    if isempty(labels)
        dendrogram(Z,0);
    elseif ~isempty(labels)
        dendrogram(Z,P,'Labels',labels,'Orientation','left');
    end
end

% % Get idx
% idx = cluster(Z,'maxclust',k);
% 
% % Evaluate solution
% c = cophenet(Z,D);