function wholestring = strerase(wholestring,substring)
% function wholestring = strcontain(wholestring,substring)
%
% Remove substring from string
%   
%--------------------------------------------------------------------------
%
% Use:
%   output = strerase('rogier','gier');
%
% Obligatory inputs:
%   wholestring     string
%   substring       string
%
% version history
% 2018-02-15	Rogier  created
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2016-02-15
%--------------------------------------------------------------------------

wholestring(strfind(wholestring,substring):strfind(wholestring,substring)+length(substring)-1) = [];