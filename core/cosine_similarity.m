function cos_similarity = cosine_similarity(a,b)
% Calculate cosine similarity between column vector a and column vectors in
% b
%--------------------------------------------------------------------------
%
% Use
%   cos_similarity = costine_similarity(a,b)
%
% Input
%   a               single column vector
%   b               single/multiple column vector(s)
%
% Output
%   cos_similarity  cosine between a and b
%
% version history
% 2015-09-16	Lennart		documentation
% 2015-09-06  Rogier    Cleaned up for GitHub release
% 2015-03-09  Rogier    Fixed bug in looping over the same b all the time
% 2015-01-04  Rogier    created
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2015-01-04
%--------------------------------------------------------------------------


%===============================
%% housekeeping
%===============================

if size(a,2)>1, error('Error in MrCat:cos_similarity: input a not a column vector!'); end
if ~isequal(size(a,1),size(b,1)), error('Error in MrCat:cos_similarity: inputs not of same length!'); end


%===============================
%% Do the work
%===============================

cos_similarity = [];

for i = 1:size(b,2)
   cos_similarity(i) =  (a'*b(:,i))/(sqrt(sum(a.^2)*sum(b(:,i).^2)));
end
