function d = mahalanobis(X1,X2)
% function d = mahalanobis(X1,X2)
%
% Calculate mahalanobis distance between two vectors as proposed by Geyer
% et al. (1996, Nature, pp. 805)
%
% Inputs:
%   X1  variables*observations data matrix 
%   X2  variables*observations data matrix (so X1 and X2 should have the
%       same number of variables, but could have different nr of observations)
%
% Ouput:
%   d  	mahalanobis distance
%
% Using example on http://people.revoledu.com/kardi/tutorial/Similarity/MahalanobisDistance.html
% Example data: group1 = [2 2; 2 5; 6 5; 7 3; 4 7; 6 4; 5 3; 4 6; 2 5; 1 3]'
%               group2 = [6 5; 7 4; 8 7; 5 6; 5 4]'
%               d = 1.4104
%
% Rogier B. Mars, University of Oxford/Donders Institute, 20072015
%  13022016 RBM Added example

[k1,n1] = size(X1);
[k2,n2] = size(X2);
n = n1+n2;

xDiff = mean(X1,2)-mean(X2,2);

% Pooled covariance
centX1 = detrend(X1','constant'); centX1 = centX1';
cX1 = (1/n1) * centX1*centX1';
centX2 = detrend(X2','constant'); centX2 = centX2';
cX2 = (1/n2) * centX2*centX2';
pooledCov = (n1/n)*cX1 + (n2/n)*cX2;

% Mahalanobis distance
d = sqrt(xDiff'*inv(pooledCov)*xDiff);