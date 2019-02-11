function r = inverse_fisherz(z)
% function r = inverse_fisherz(r)
% Calculate inverse of Fisher's z-transform
%--------------------------------------------------------------------------
%
% Use:
%   r = inverse_fisherz(a)

% version history
% 2016-03-10    Rogier created
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2015-03-10
%-------------------------------------------------------------------------- 

r=(exp(2*z)-1)./(exp(2*z)+1);