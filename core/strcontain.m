function output = strcontain(wholestring,substring)
% function output = strcontain(wholestring,substring)
%
% Test whether string contains a substring
%   
%--------------------------------------------------------------------------
%
% Use:
%   output = strcontain('rogier','gier');
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

if isempty(strfind(wholestring,substring))
    output = false;
elseif ~isempty(strfind(wholestring,substring))
    output = true;
end