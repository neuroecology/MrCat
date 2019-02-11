function dc = dice(data1,data2)
% function dc = dice(data1,data2)
%
% Calculate average Sørensen?Dice coefficient for all elements in data1
%
%--------------------------------------------------------------------------
%
% Use:
%   dc = dice(data1,data2)
%
% Obligatory inputs:
%   data1    data vector
%   data2    data vector
%
% version history
% 2018-02-23	Rogier  created
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2018-02-23
%--------------------------------------------------------------------------

if ~isvector(data1) || ~isvector(data2)
    error('Error in MrCat:dice: input is not a vector!');
end

for i = unique(data1)
    dc = (2*length(find(data2(find(data1==i))==i))) / (length(data1)+length(data2));
end

