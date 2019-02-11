function surf_crosscorr(dataRoi, dataBrain, hemiMask, outName, flgDimRed)

% % test data
% dataRoi = fullfile('~','Desktop','test','roi.dconn.nii');
% dataBrain = fullfile('~','Desktop','test','L.dconn.nii');
% hemiMask = fullfile('~','Desktop','test','hemi.shape.gii');
% outName = fullfile('~','Desktop','test','test');
% flgPCA = true;

% do PCA dimension reduction by default
if nargin < 5 || isempty(flgDimRed), flgDimRed = true; end

% load data
fprintf('Reading data...\n');
dataRoi = readimgfile(dataRoi);
dataBrain = readimgfile(dataBrain);

% find on which row A is a subset of B
fprintf('Matching ROI to data...\n');
nRoi = size(dataRoi,1);
idxRoi = nan(nRoi,1);
for c = 1:nRoi
  idxRoi(c) = find(all(repmat(dataRoi(c,:),size(dataBrain,1),1)==dataBrain,2));
end

% replace values on the diagonal and normalise
fprintf('Normalising data...\n');
n = size(dataBrain,1);
dataBrain(1:(n+1):numel(dataBrain)) = 1;
dataBrain = normalise(dataBrain,2);
if ~any(isnan(idxRoi))
  dataRoi = dataBrain(idxRoi,:);
else
  dataRoi(dataRoi>2) = 1;
  dataRoi = normalise(dataRoi,2);
end

% reduce the dimensionality (if >1000) of the connectivity matrix 
flgDimRed = flgDimRed && size(dataRoi,2) > 1000;
if flgDimRed
  if any(isnan(idxRoi))
    fprintf('dataRoi is not a subset of dataBrain, dimensionality cannot be reduced...\n');
  else
    fprintf('Reducing dimensionality... Relax, sit back, and enjoy your break...\n');
    % REMARK: this is computationally a very very expensive step!
    nComp = round(size(dataBrain,1)/100);
    % run principal component analysis
    [~,dataBrain] = pca(dataBrain','NumComponents',nComp);
    % normalise connectivity map so that following dot-product
    % results in a correlation coefficient (corrcoef).
    dataBrain = normalise(dataBrain,2);
    dataRoi = dataBrain(idxRoi,:);
  end
end

% Calculate cross-correlation matrix
% - NOTE dimension: roi x target
fprintf('Calculating similarity measure...\n');
% compute a connectivity map of roi x all
% the dot-product of normalised data indeces the covariance
% of roi dataseries with that of all other vertices
% REMARK: this is a computationally expensive step!
CC = dataRoi * dataBrain';
% fix possible round-off problems
t = find(abs(CC) > 1); CC(t) = CC(t)./abs(CC(t));

% load the roi
hemiMask = gifti(hemiMask);

% assign values to the roi vertices
idxMask = hemiMask.cdata>0;
hemiMask.cdata = zeros(size(hemiMask.cdata,1),nRoi);
hemiMask.cdata(idxMask,:) = CC';

% Save solutions to a func gifti file
fprintf('Backprojecting...\n');
create_func_gii(hemiMask.cdata, outName, 'L');
