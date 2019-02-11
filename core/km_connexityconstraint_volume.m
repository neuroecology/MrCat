function CC = km_connexityconstraint_volume(CC, roi_path, varargin)
% Function to calculate distance matrix of all the voxels in a region of
% interest defined using coords_for_fdt_matrix2 and combine it with a
% previously calculated cross-correlation matrix. For use with kmeans.fdt.m
%--------------------------------------------------------------------------
%
% Use
%   km_connexityconstraint_volume(CC, path_to_ROI, path_to_surface_file)
%
% Obligatory input:
%   CC          cross-correlation matrix
%   roi_path    path to your region of interest .nii.gz volume file)
%
% Optional inputs (using parameter format):
%   fudge_factor    takes values in range [0 1]
%                   0.2 (default)
%   dist_method     method to be used to calculate distances
%                   'euclid' (default), 'cityblock', or any option from
%                   pdist
%   nonconnected    vector with ones for unconnected voxels in the CC
%
% Output
%   CC          weighted combination of cross-correlation matrix and
%               distance matrix
%
% To do: implement to work with volume .nii.gz instead of coords
%
% version history
% 2016-07-20    Rogier  added facility to deal with non-connected voxels
% 2016-05-13    Rogier  added facility to work with volume .nii.gz
% 2016-05-12	Rogier  created
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2016

%==================================================================
% Housekeeping
%==================================================================

% defaults
con     = 0.2; % con is the fudge factor between 0 and 1
dist    = 'euclid';
D       = [];
nonconnected = [];

if nargin>3
    for vargnr = 2:2:length(varargin)
        switch varargin{vargnr-1}
            case 'fudge_factor'
                con = str2double(varargin{vargnr});
            case 'dist_method'
                dist = varargin{vargnr};
            case 'nonconnected'
                nonconnected = varargin{vargnr};
        end
    end
end

%==================================================================
% Do the work
%==================================================================

%------------------------------------------------
% Load data
%------------------------------------------------

[~,~,ext] = fileparts(roi_path);
if isempty(ext)

    coord = load(roi_path)+1;
    
elseif (isequal(ext,'.gz') || isequal(ext,'.nii'))
    
    data = binarize(readimgfile(roi_path));
    [coord(:,1),coord(:,2),coord(:,3)] = ind2sub(size(data),find(data==1));
    clear data;
    
end

%------------------------------------------------
% Calculate distance
%------------------------------------------------

D = squareform(pdist(coord,dist));

%------------------------------------------------
% Deal with nonconnected voxels (if requested)
%------------------------------------------------

if sum(nonconnected)>0
    D(find(nonconnected==1),:) = [];
    D(:,find(nonconnected==1)) = [];
end

save nonconnected nonconnected

%------------------------------------------------
% scale D to min and max of both CC and D
%------------------------------------------------

D = max(D(:))-D;
m = min(D(:));
M = max(D(:));
R = max(CC(:));
r = min(CC(:));
D = (D-m)*(R-r)/(M-m)+r;

size(D)
size(CC)

%------------------------------------------------
% weighted combination of CC and D to submit to clustering algorithm
%------------------------------------------------

fprintf('Combining CC and D with a fudge factor of: %.2f \n \n', con);
CC = sqrt( (1-con)*CC.*CC + con*D.*D);
