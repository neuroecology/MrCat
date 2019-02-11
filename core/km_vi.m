function VI = km_vi(idx)
% Calculate variation of information metric (Meila, 2007 following Kahnt
% et al.,2012, J Neurosci) between cluster solutions
%--------------------------------------------------------------------------
%
% Use
%   VI = km_vi(idx)
%
% Input
%   idx     number_of_voxels*number_of_solutions
%
% Output
%   VI      variation of information metric vector
%
% Dependency
%   columnentropy.m
%   mutualinformation.m
%
% version history
% 2015-09-16	Lennart		documentation
% 2015-09-01  Rogier    housekeeping
% 2015-08-12  Rogier    Allow comparison of more than two solutions
% 2014-02-18  Rogier    created
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2014-02-18
%--------------------------------------------------------------------------


%===============================
%% housekeeping
%===============================

if (size(idx,2)==1), error('Error in MrCat:km_vi: Input idx has wrong number of columns in km_vi.m!'); end


%===============================
%% Do the work
%===============================

VI = [];

for c = 2:size(idx,2)
    VI(c-1) = columnentropy(idx(:,c-1)) + columnentropy(idx(:,c)) - 2*mutualinformation([idx(:,c-1) idx(:,c)]);
end

% Note: if there are k clusters, with K<=sqrt(n), then VI<=2log(k)
