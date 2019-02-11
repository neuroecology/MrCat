function rsn_cleanCompSimple(fnameIn,X,fnameOut,fnameOutBeta,fnameOutTstat,fnameOutConfound)
% rsn_cleanCompSimple
% Produces fnameOut after regressing X out of fnameIn.
% Store beta maps in fnameOutBeta (skip if left empty).
% Store t-stat maps in fnameOutTstat (skip if left empty).
% Store confound timeseries in fnameOutConfound (skip if left empty).
%
% fnameIn data is NxP and X is NxQ
%--------------------------------------------------------------------------
%
% version history
% 2017-11-07    Lennart changed padname to fnameOut
% 2017-05-29    Lennart improved memory and cpu footprint
% 2017-05-25    Lennart allowed flexible inputs
% 2017-04-12    Rogier  changed file handling to use load/save_nifti
% 2016-03-23    Rogier  added to MrCat, based on Saad's original
%
%--------------------------------------------------------------------------
if nargin<3, fnameOut = ''; end
if nargin<4, fnameOutBeta = ''; end
if nargin<5, fnameOutTstat = ''; end
if nargin<6, fnameOutConfound = ''; end
if isempty(fnameOut) && isempty(fnameOutBeta) && isempty(fnameOutTstat) && isempty(fnameOutConfound)
  error('MRCAT:rsn_cleanCompSimple:NO_OOUTPUT','Please specify at least one output file in fnameOut, fnameOutBeta, fnameOutTstat, or fnameOutConfound.');
end

%==================================================
% Load confounds
%==================================================

% switch on input type
if iscell(X)
  X = X(:)';
  for c = 1:length(X)
    X{c} = load(X{c});
  end
  X = cell2mat(X);
elseif ischar(X)
  X = load(X);
end

% normalise the variance of the components
X = normalise(X,1);


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
% Regress out
%==================================================
fprintf('regressing confound signals from data\n');
% run generalized linear model to regress out the confounds

% set output depending on request
if isempty(fnameOutTstat)
  
  % performing GLM (skip t-statistic for speed)
  [y, betaConf, yConf] = regress_out(y,X);
  
else
  
  % performing GLM and calculating t-statistic
  [y, betaConf, yConf, tstat] = regress_out(y,X);
  
end


%==================================================
% Reshape and save
%==================================================

% save the cleaned data
if ~isempty(fnameOut)
  fprintf('saving cleaned data\n');

  % place data back into original format (overwrite the input hdr.vol)
  hdr.vol = reshape(y',dims);

  % save the filtered image
  save_nifti(hdr,fnameOut);
  
end

% save the beta maps
if ~isempty(fnameOutBeta)
  fprintf('saving confound betas\n');
  
  % place data back into original format (overwrite the input hdr.vol)
  dimsBeta = dims;
  dimsBeta(4) = size(betaConf,1);
  hdr.vol = reshape(betaConf',dimsBeta);

  % save the filtered image
  save_nifti(hdr,fnameOutBeta);
  
end

% save the tstat maps
if ~isempty(fnameOutTstat)
  fprintf('saving confound t-stats\n');
  
  % place data back into original format (overwrite the input hdr.vol)
  dimsTstat = dims;
  dimsTstat(4) = size(tstat,1);
  hdr.vol = reshape(tstat',dimsTstat);

  % save the filtered image
  save_nifti(hdr,fnameOutTstat);
  
end

% save the confound timeseries
if ~isempty(fnameOutConfound)
  fprintf('saving confound time-series\n');
  
  % place data back into original format (overwrite the input hdr.vol)
  hdr.vol = reshape(yConf',dims);

  % save the filtered image
  save_nifti(hdr,fnameOutConfound);
  
end
