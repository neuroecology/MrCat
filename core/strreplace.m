function wholestring = strerase(wholestring,old,new)
% function wholestring = strcontain(wholestring,odl,new)
%
% Replace substring from string
%   
%--------------------------------------------------------------------------
%
% Use:
%   output = strreplace('rogier','g');
%
% Obligatory inputs:
%   wholestring     string
%   old             substring to be replaced
%   new             substring of same length as old
%
% version history
% 2018-03-09	Rogier  created
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2018-03-09
%--------------------------------------------------------------------------

wholestring(strfind(wholestring,old):strfind(wholestring,old)+length(old)-1)=new;