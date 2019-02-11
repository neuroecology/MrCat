function output = maskmean(data,mask)
%
% function output = maskmean(data,mask)
%
% Give mean of the data locations that have a value >0 in the mask
%
% Rogier B. Mars, University of Oxford, 01062012
% 13022018 RBM addded data(:) step
% 19012013 RBM Changed algorithm after detecting strange behavior

data = data(:);
output = mean(data(find(mask>0)));

% data = data(:); mask = mask(:);
% 
% data(find(mask==0)) = [];
% 
% output = mean(data);