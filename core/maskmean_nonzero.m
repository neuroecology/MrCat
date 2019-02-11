function output = maskmean_nonzero(data,mask)
%
% function output = maskmean_nonzero(data,mask)
%
% Give mean of the non-zero data locations that have a value >0 in the mask
%
% Rogier B. Mars, University of Oxford, 11112014

data = data(:);
data = data(find(mask>0));
data(find(data(:,1)==0),:) = [];

output = mean(data);