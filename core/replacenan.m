function data = replacenan(data,value)
% function data = replacenan(data,value)
%
% Replace nan by value
%
% Rogier B. Mars, University of Oxford, 11092012
% 28072015 RBM Made efficient

data(isnan(data)) = value;