function out = threshold(data,criterion)
% function out = threshold(data,criterion)
%
% Zero everything above criterion
%--------------------------------------------------------------------------
%
% version history
% 14042016 RBM MrCat compatible
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2012-04-10
        
out = data;
out(find(data>criterion))=0;