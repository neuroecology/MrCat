function rsn_detrend(fnameIn,fnameOut,outlierFile)
% rsn_detrend
% Detrends fnameIn using linear regression, ignoring outliers as marked in
% outlierFile (val>0).
%
% fnameIn data is NxP and outlierFile is Nx1
%--------------------------------------------------------------------------
%
% version history
% 2018-04-30    Lennart created
%
%--------------------------------------------------------------------------



%==================================================
% Load and reshape data
%==================================================
fprintf('loading data\n');

[y, ~, hdr] = readimgfile(fnameIn);

% restructure the data matrix
dims = size(y);
nVox = prod(dims(1:3));
nTim = dims(4);
y = reshape(y,nVox,nTim)';


%==================================================
% build linear trend model (ignoring outliers)
%==================================================
X = (1:nTim)';

% add outlier regressors
if nargin > 2 && ~isempty(outlierFile)
  
  % read in the outlier file
  idxOut = find(load(outlierFile)>0);
  nOut = numel(idxOut);
  
  % if outliers are detected
  if nOut>0
    
    % build singular regressors for the ourlier volumes
    Xoutlier = zeros(nTim,nOut);
    for c = 1:nOut
      Xoutlier(idxOut(c),c) = 1;
    end
    
    % combine the outlier regressors with the main model
    X = [X Xoutlier];
    
  end
  
end


%==================================================
% Regress out
%==================================================
fprintf('regressing linear trend from data\n');

% regress out the linear trend
idxTrend = 1;
try

  y = regress_out(y,X,idxTrend);

catch

  % add constant to the model to remove mean
  yMean = mean(y,1);
  X = [ones(nTim,1) X];
  idxTrend = [1 idxTrend+1];

  % estimate beta (using matrix left divide for pseudo-inverse)
  betaConf = X\y;

  % retrieve residuals after removing fitted confounds
  y = y - X(:,idxTrend) * betaConf(idxTrend,:);

  % put mean signal back in
  y = bsxfun(@plus,y,yMean);

end


%==================================================
% Reshape and save
%==================================================
fprintf('saving cleaned data\n');

% place data back into original format (overwrite the input hdr.vol)
hdr.vol = reshape(y',dims);

% save the filtered image
save_nifti(hdr,fnameOut);
