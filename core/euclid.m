function d = euclid(a,b,axdim)
% Calculate Euclidian distance between points of matrices a and b. You can
% define the dimension in which the axis are specified. By default
% ('auto') the first dimension of size 3 (x, y, and z-axes) is used, and if
% none found, the first dimension of size 2 (x and y-axes) is used instead.
%
% Use:
%   d = euclid(a,b,axdim)
%
% version history
% 2015-10-23  Rogier    Documentation
% 2015-07-24  Lennart   First release of matlab-public-lennart
%
% copyright
% Lennart Verhagen
% University of Oxford, 2015-07-24

if nargin < 3 || isempty(axdim)
    axdim = 'auto';
end

siz = size(a);
if nargin < 2 || isempty(b)
    dim = find(siz==2);
    if length(dim) ~= 1
        error('MrCat:euclid:InputDim','One input matrix is given but the dimension over which to calculate the distance is unknown');
    else
        ab = diff(a,1,dim);
        siz(dim) = [];
        siz = [siz ones(1,length(siz)-2)];
        ab = reshape(ab,siz);
        if ~isequal(axdim,'auto') && dim < axdim
            axdim = axdim - 1;
        end
    end
else
    if ~isequal(size(b),siz)
        ab = bsxfun(@minus,b,a);
    else
        ab = b - a;
    end
end

% find dimension of axis
if isequal(axdim,'auto')
    axdim = find(siz==3,1);
    if isempty(axdim)
        axdim = find(siz==2,1);
    end
end

% calculate Euclidian distance (using Pythagoras)
d = squeeze(sqrt(sum(ab.^2,axdim)));