function asymmetry_index = asymmetry(right,left)
% function asymmetry_index = asymmetry(right,left)
%
% Calculate assymmetry index (right positive, left negative) of the summed
% value of two matrices
%--------------------------------------------------------------------------
%
% version history
% 2017-03-07 Rogier     added documentation
% 2017-02-17 Rogier     created
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2017-02-17
%--------------------------------------------------------------------------

right = sum(right(:)); left = sum(left(:));
asymmetry_index = (right-left)/(right+left);