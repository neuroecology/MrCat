function etas = eta_template(varargin)
% function etas = eta_template(varargin)
%
% Follows Cohen et al (2008) NeuroImage 41:45-57
%
% Inputs:
%   data            structure with a volume of correlations for each seed
%   templatenr      nr of the volume that you want to compare against
%   constrainmask   a 3D matrix containing 1's for the voxels you want to
%                   use and 0's otherwise (optional)
%
% Rogier B. Mars, University of Oxford, 04072013
% 05072013 RBM Changed to accept varargin, making mask optional

%===================================================
% Housekeeping
%===================================================

if nargin==2
    data = varargin{1};
    templatenr = varargin{2};
    constrainmask = [];
elseif nargin==3
    data = varargin{1};
    templatenr = varargin{2};
    constrainmask = varargin{3};
else error('Wrong number of input arguments for eta_template.m!');
end

%===================================================
% Do the work
%===================================================

for sd = 1:length(data)

     a = data{templatenr}(:);
     
     b = data{sd}(:);
     
     if ~isempty(constrainmask)
        constrainmask = constrainmask(:);
        a(find(constrainmask==0),:) = [];
        b(find(constrainmask==0),:) = [];
     end
     
     m = (a+b)./2;
     
     M = mean(m(:));
     
     teller = sum(((a-m).^2) + ((b-m).^2));
     noemer = sum(((a-M).^2) + ((b-M).^2));
     
     etas(sd) = 1 - (teller/noemer);
     
end