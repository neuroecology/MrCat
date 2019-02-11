function x = normalise(x,dim,unistd)
% Remove the mean value and make the std = 1
%--------------------------------------------------------------------------
%
% Use:
%   normalise(X,DIM)

% version history
% 2018-10-16    Rogier 	back to original version to keep it working
% 2018-04-18    Lennart improved computational and memory load
% 2016-03-08    Rogier  created, based on Saad Jbabdi's original
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2015-03-08
%--------------------------------------------------------------------------

if(nargin==1),
   dim = 1;
   if(size(x,1) > 1)
      dim = 1;
   elseif(size(x,2) > 1)
      dim = 2;
   end;
end;
if(nargin<=2)
    unitstd=0;
end

dims = size(x);
dimsize = size(x,dim);
dimrep = ones(1,length(dims));
dimrep(dim) = dimsize;


x = bsxfun(@minus,x,nanmean(x,dim));
x = bsxfun(@times,x,1./nanstd(x,0,dim));

% x = x - repmat(nanmean(x,dim),dimrep);
% x = x./repmat(nanstd(x,0,dim),dimrep);
x(isnan(x)) = 0;

if(~unitstd==1)
    x = x./sqrt(dimsize-1);
end
