function out = threshold(data,criterion)
% function out = threshold(data,criterion)
%
% Zero everything below criterion
%--------------------------------------------------------------------------
%
% version history
% 14042016 RBM MrCat compatible
% 10042012 RBM Created
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2012-04-10
%--------------------------------------------------------------------------

out = data;
out(find(data<criterion))=0;