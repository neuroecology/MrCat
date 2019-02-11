function x=demean(x,dim)
% function x = demean(x,dim)
% Removes the average or mean value along dimension dim of x
%--------------------------------------------------------------------------
%
% version history
% 2017-06-01    Lennart imrpoved memory and computation performance
% 2016-06-22    Rogier  MrCat version
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2016
%-------------------------------------------------------------------------- 

% find the first non-singleton dimension, if dim is not provided
if nargin < 2,  dim = find(size(x)>1,1,'first'); end

% use bsxfun to subtract matrices that match on all but one dimension
x = bsxfun(@minus,x,mean(x,dim));

% Saad's original
%
% if(nargin==1)
%    dim = 1;
%    if(size(x,1) > 1)
%       dim = 1;
%    elseif(size(x,2) > 1)
%       dim = 2;
%    end
% end
%
% dims = size(x);
% dimsize = size(x,dim);
% dimrep = ones(1,length(dims));
% dimrep(dim) = dimsize;
% 
% x = x - repmat(mean(x,dim),dimrep);
