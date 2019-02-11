function d = manhattan(template,data)
% Calculate Mahattan distances between vectors
%--------------------------------------------------------------------------
% Use
%   out = manhattan(template,data)
%
% Input
%   template    arms*1 template vector
%   data        arms*spiders data matrix
%
% Output
%   out         1*spiders vector of mahattan distances
%
% version history
% 2018-05-11	Lennart		efficiency
% 2015-09-16	Lennart		documentation
% 2015-09-06  Rogier    Cleaned up for GitHub release
% 2015-01-02  Rogier    Vectorised for efficiency
% 2013-11-19  Rogier    created
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2013-11-19
%--------------------------------------------------------------------------


%===============================
%% Housekeeping
%===============================

if size(template,1)~=size(data,1), error('MrCat:mahattan:Size of inputs do not match!'); end


%===============================
%% Do the work
%===============================

% vectorised Manhattan distance
% d = sum(abs(repmat(template,1,size(data,2)) - data),1);
d = sum(abs(bsxfun(@minus,template,data)),1);
