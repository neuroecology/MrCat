function [L,thrdata,varargout] = cluster_threshold(data,height,extent,varargin)
% function [L,thrdata,varargout] = cluster_threshold(data,height,extent,varargin)
%
% Threshold 3D matrix based on cluster height and extent
%--------------------------------------------------------------------------
%
% Use:
%   [L,thrdata] = cluster_threshold(data,2.5,10)
%   [L,thrdata,reporttable] = cluster_treshold(data,2.5,10)
%
% Obligatory inputs:
%   data    data matrix
%   height  height threshold (inclusive)
%   extent  extent threshold (inclusive)
%
% Optional inputs (using parameter format):
%   conn            desired connectivity following bwlabeln, 6 default
%   report_table    'yes' (default) or 'no'
%
% Obligatory outputs:
%   L       thresholded matrix with numbers for each significant cluster
%   thrdata thresholded original matrix
%
% Optional outputs:
%   varargout{1}    report table containing for each cluster a row with the
%                   cluster number, the x,y,z coords, and the size
%   varargout{2}    bw
%
% version history
% 11092018 RBM Added bw optional output
% 11112016 RBM Bug fix in report_table option
% 21102016 RBM Fixed bug in table reporting leading to a massive rewrite
% 18072016 RBM Added table output varagout{1}
% 17072016 RBM Added table reporting
% 14042016 RBM MrCat compatible
% 02042015 RBM Created
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2015-04-02
%--------------------------------------------------------------------------


%===============================================
% Housekeeping
%===============================================

% Defaults
conn = 6;
report_table = 'yes';

% Optional inputs
if nargin>2
    for vargnr = 2:2:length(varargin)
        switch varargin{vargnr-1}
            case 'conn'
                conn = varargin{vargnr};
            case 'report_table'
                report_table = varargin{vargnr};
        end
    end
end

%===============================================
% Do the work
%===============================================

% Threshold based on height
data = threshold(data,height);

% Get cluster information
bw = bwconncomp(data);

% Reporting
thrdata = zeros(size(data));
L = zeros(size(data));

report = [];

cnt = 1;
for c = 1:length(bw.PixelIdxList)

    if length(bw.PixelIdxList{c}) >= extent

        thrdata(bw.PixelIdxList{c}) = data(bw.PixelIdxList{c});

        L(bw.PixelIdxList{c}) = cnt;

        % Get a coordinate
        tmp = zeros(size(data)); tmp(bw.PixelIdxList{c})=1;
        [i,j,k] = ind2sub(size(tmp),find(tmp==1));

        % Create cluster row
        report = [report; [cnt i(1) j(1) k(1) length(bw.PixelIdxList{c})]];

        cnt = cnt + 1;

    end

end

% Sort
report = sortrows(report,-5);

% Write report to screen
switch report_table
    case 'yes'
        fprintf('Clusters (by size):\n');
        fprintf('Clust_ID\tClust_loc\tClust_size\n');
        fprintf('==========================================\n');
        for c = 1:size(report,1)
            fprintf('%i\t\t%i %i %i\t%i\n',report(c,1),report(c,2),report(c,3),report(c,4),report(c,5));
        end
end

varargout{1} = report;
varargout{2} = bw;
