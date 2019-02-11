function z = fisherz(r)
% function z = fisherz(r)
% Calculate Fisher's z-transform of the correlation coefficient r
%--------------------------------------------------------------------------
%
% Use:
%   z = fisherz(r)

% version history
% 2016-03-10    Rogier created
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2015-03-10
%-------------------------------------------------------------------------- 

z=.5.*log((1+r)./(1-r));