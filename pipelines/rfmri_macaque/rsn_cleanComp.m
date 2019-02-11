function rsn_cleanComp(fnameIn,compSignal,compNoise,compNoiseAggressive,fnameOut)
% function rsn_cleanComp(fnameIn,compSignal,compNoise,compNoiseAggressive,fnameOut)
%
% Removing compSignal components that match compNoise (r>0.6) from fnameIn
% Additionally regressing out compNoiseAggressive; leave empty [] to skip.
%
% fnameIn data is NxP, compSignal is NxQ, compNoise is NxR
%
% TODO: the function rsn_cleanCompSimple should probably be merged into this more
% elaborate version, but then inputs should probably be specified in a
% param-value format to allow simple input argument specifications
%--------------------------------------------------------------------------
%
% version history
% 2018-04-15    Lennart implementing soft regression
% 2018-04-14    Lennart fork of rsn_cleanCompSimple allowing signal component matching
% 2017-11-07    Lennart changed padname to fnameOut
% 2017-05-29    Lennart improved memory and cpu footprint
% 2017-05-25    Lennart allowed flexible inputs
% 2017-04-12    Rogier  changed file handling to use load/save_nifti
% 2016-03-23    Rogier  added to MrCat, based on Saad's original
%
%--------------------------------------------------------------------------

% in addition to removing all matched signal components, also remove either
% all noise components, only the unmatched ones, or none
flgRemoveNoise = 'all'; % 'all', 'unmatched', 'none'

% aggressively remove all variance associated with the noise, or do a soft
% regression where only the unique variance is taken out
flgRegrVar = 'unique'; % 'full', 'unique'

% sort input

%==================================================
% Load signals and confounds
%==================================================

% switch on compSignal input type
if isempty(compSignal), compSignal = []; end
if iscell(compSignal)
  compSignal = compSignal(:)';
  for c = 1:length(compSignal)
    compSignal{c} = load(compSignal{c});
  end
  compSignal = cell2mat(compSignal);
elseif ischar(compSignal)
  compSignal = load(compSignal);
end

% switch on compNoise input type
if isempty(compNoise), error('please provide a compNoise matrix as input'); end
if iscell(compNoise)
  compNoise = compNoise(:)';
  for c = 1:length(compNoise)
    compNoise{c} = load(compNoise{c});
  end
  compNoise = cell2mat(compNoise);
elseif ischar(compNoise)
  compNoise = load(compNoise);
end

% switch on meanNoise input type
if isempty(compNoiseAggressive), compNoiseAggressive = []; end
if iscell(compNoiseAggressive)
  compNoiseAggressive = compNoiseAggressive(:)';
  for c = 1:length(compNoiseAggressive)
    compNoiseAggressive{c} = load(compNoiseAggressive{c});
  end
  compNoiseAggressive = cell2mat(compNoiseAggressive);
elseif ischar(compNoiseAggressive)
  compNoiseAggressive = load(compNoiseAggressive);
end

% normalise the variance of the components
compSignal = normalise(compSignal,1);
compNoise = normalise(compNoise,1);
compNoiseAggressive = normalise(compNoiseAggressive,1);


%==================================================
% Identify signal confounds based on noise
%==================================================
fprintf('identifying signal components that match noise confounds\n');

% correlate signal and noise components
R = abs(corr(compSignal,compNoise));

% for each signal component take the best match across all noise components
r = max(R,[],2);

% classify signal components either as a match to the noise or not
rMatch = 0.6;
idxMatch = find(r > rMatch);

% if too many or too few signal components have been identified
nCompNoise = size(compNoise,2);
nCompSignal = size(compSignal,2);
if numel(idxMatch) > (2 * nCompNoise)
  % too many components have been identified

  % take top 2*nCompNoise best matches
  nComp = min(2*nCompNoise,nCompSignal);
  [~,idxMatch] = sort(r,'descend');
  idxMatch = idxMatch(1:nComp);

elseif numel(idxMatch) < (nCompNoise / 2)
  % too few components have been identified

  % take top nCompNoise/2 best matches (but cap at nCompSignal)
  nComp = min(nCompNoise/2,nCompSignal);
  [~,idxMatch] = sort(r,'descend');
  idxMatch = idxMatch(1:nComp);

  % test for weak correlations
  if ~any( r(idxMatch) > (rMatch/2) )

    % only weak correlations found, stopping here
    fprintf('no noise components identified\n');
    fprintf('copying input to output\n');
    unix(['cp ' fnameIn ' ' fnameOut]);
    return

  else

    % keep only matches with r > (rMatch/2)
    idxMatch = idxMatch( r(idxMatch) > (rMatch/2) );

  end

end

% create a set of signal and noise regressors to model the data
X = [compSignal compNoise];

% in addition to removing all matched signal components, also remove either
% all noise components, only the unmatched ones, or none
idxNoise = idxMatch(:)';
if strcmpi(flgRemoveNoise,'all')

  % also remove all noise components
  idxNoise = [idxNoise nCompSignal+(1:nCompNoise)];

elseif strcmpi(flgRemoveNoise,'unmatched')

  % identify which noise components are not matched to signal
  idxCompNoiseUnmatched = all(R<min(r(idxMatch)),1);

  % also remove unmatched noise components
  idxNoise = [idxNoise nCompSignal+idxCompNoiseUnmatched];

end


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
fprintf('regressing signal confounds from data\n');

% perpare the model and noise indices based on the regression type
if strcmpi(flgRegrVar,'unique')

  % for soft regression, first remove the compNoiseAggressive from data and model
  try

    y = regress_out(y,compNoiseAggressive);
    X = regress_out(X,compNoiseAggressive);

  catch

    % add constant to the model to remove mean
    yMean = mean(y,1);
    XMean = mean(X,1);
    compNoiseAggressive=[ones(nTim,1) compNoiseAggressive];

    % estimate beta (using matrix left divide for pseudo-inverse)
    betaYConf = compNoiseAggressive\y;
    betaXConf = compNoiseAggressive\X;

    % retrieve fitted confound signals
    yConf = compNoiseAggressive*betaYConf;
    XConf = compNoiseAggressive*betaXConf;

    % retrieve residuals after removing fitted confounds
    y = y-yConf;
    X = X-XConf;

    % put mean signal back in
    y = bsxfun(@plus,y,yMean);
    X = bsxfun(@plus,X,XMean);

  end

else

  % for aggressive regression, ignore the signal components
  X = [X(:,idxNoise) compNoiseAggressive];
  idxNoise = 1:size(X,1);

end

% regress out the main noise components
try

  y = regress_out(y,X,idxNoise);

catch

  % add constant to the model to remove mean
  yMean = mean(y,1);
  X = [ones(nTim,1) X];
  idxNoise = [1 idxNoise+1];

  % estimate beta (using matrix left divide for pseudo-inverse)
  betaConf = X\y;

  % retrieve residuals after removing fitted confounds
  y = y - X(:,idxNoise) * betaConf(idxNoise,:);

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
