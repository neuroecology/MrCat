function [yR, betaConf, yConf, tstat] = regress_out(y,X,idx)
% function [yR, betaConf, yConf, tstat] = regress_out(y,X,idx)
% Produces yR after regressing X out of y. The full model X is fitted, but
% only X(idx) are removed ('soft regression'). By default idx is set to the
% full model ('aggressive regression').
%
% Please note that the the regressors in model X are not explicitly
% variance normalised, nor demeaned.
%
% y and yR are NxP and X is NxQ
%--------------------------------------------------------------------------
%
% version history
% 2018-05-15    Lennart added t-statistic
% 2018-04-15    Lennart added 'soft' regression option
% 2017-06-01    Lennart improved memory and computation performance
% 2016-03-23    Rogier  added to MrCat, based on Saad's original
%
%--------------------------------------------------------------------------

% specify idx input
if nargin < 3 || isempty(idx), idx = 1:size(X,2); end
if islogical(idx) || all(idx==1 | idx==0), idx = find(idx); end
idx = idx(:)';

% add constant to the model to remove mean
yMean = mean(y,1);
flgMean = false;
if any(yMean(:) > 1e-12)
  X = [ones(size(X,1),1) X];
  idx = [1 idx+1];
  flgMean = true;
end

% estimate beta (using matrix left divide for pseudo-inverse)
betaConf = X\y;

% retrieve fitted confound signals
yConf = X(:,idx) * betaConf(idx,:);

% retrieve residuals after removing fitted confounds
yR = y - yConf;

% calculate t-statistic
if nargout > 3
  % degrees of freedom
  n = size(X,1);
  p = numel(idx);
  dof = n-p;
  % mean squared error
  % mse = (yR'*yR)/dof;
  mse = sum(yR'.^2,2)/dof;
  % initialise t-stat
  tstat = nan(numel(idx),size(y,2));
  % loop over contrasts
  for cc = 1:numel(idx)
    c = zeros(1,numel(idx));
    c(cc) = 1;
    % standard error
    se = sqrt(mse*c/(X(:,idx)'*X(:,idx))*c');
    % t-statistic
    tstat(cc,:) = (c*betaConf(idx,:))'./se;
  end
  % replace nans by zeros
  tstat(isnan(tstat)) = 0;
  
end

% put mean signal back in (if present)
if flgMean
  yR = bsxfun(@plus,yR,yMean);
end
