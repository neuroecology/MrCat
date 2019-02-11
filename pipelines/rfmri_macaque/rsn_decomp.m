function dataComp = rsn_decomp(data,nComp,flgMethod,basenameOut)
% Decompose the data timeseries into principal or independent components. Please
% note that by default the mean will be extracted and returned, counting as one
% component. For example, if you want to extract two eig/PCA/ICA components in
% addition to the mean, you should set nComp = 3.
%
% Example usage:
%   rsn_decomp(data,3,'pca','you/are/here.nii.gz')
%   rsn_decomp('data.nii.gz',3)
%   rsn_decomp({'data.nii.gz','mask.nii.gz'},3,'pca','you/are/here.nii.gz')
%
% REQUIRED
%   data    - data timeseries in a observations x time-points matrix.
%             Alternatively, the data can be read in from an image file
%             (please specify as a string), potentially masked by another
%             image (please specify as a 1x2 cell string).
%   nComp   - number of components
%
% OPTIONAL
%   flgMethod     - 'none', 'eig', 'pca' (default), and 'ica'
%                   Please note that the 'ica' is slow when nVox >> nTim
%                   because it relies on the nVox x nVox covariance matrix.
%   basenameOut   - a base name to save the components as a text file. The
%                   extension is ignored and the basename is post-padded
%                   with '_mean' and '_comp1' and so forth.
%
% OUTPUT
%   dataComp  - data components in a time-points x components matrix.
%
%
% (c) Lennart Verhagen, 2017-2018

% overhead
narginchk(2,4);
if nargin<4 || isempty(basenameOut), basenameOut = ''; end
if nargin<3 || isempty(flgMethod), flgMethod = 'pca'; end
if isempty(nComp), error('please specify the number of components'); end
if isempty(data), error('please provide input data as a matrix, string, or 1x2 cell string'); end
mask = '';

% parse the data and mask input
if iscell(data)
  mask = data{2};
  data = data{1};
end

% read in the data, if a string is provided
if ischar(data)
  data = readimgfile(data);
  % restructure the data matrix
  dims = size(data);
  nVox = prod(dims(1:3));
  nTim = dims(4);
  data = reshape(data,nVox,nTim);
end

% please note:
% for the data voxels are on the 1st axis (rows) and time is on the 2nd axis (columns)
% for the components, time is on the 1st axis and components are on the 2nd axis

% apply the mask, if requested
if ~isempty(mask)
  % read in the mask
  mask = readimgfile(mask);
  mask = reshape(mask,size(data,1),1);
  % exclude voxels outside the mask
  data = data(mask>0,:);
end

% de-mean the data
data = bsxfun(@minus,data,mean(data,2));

% calculate the mean timeseries
dataMeanTS = mean(data,1)';
nTim = size(dataMeanTS,1);

% consider the mean timeseries as the first component and move on to the next components
nComp = nComp - 1;

% do not decompose if no components are requested
if nComp < 1, flgMethod = 'none'; end

% decompose data timeseries based on chosen method
dataVal = []; dataExpl = [];
switch flgMethod
  case 'none'
    dataComp = zeros(size(data,2),0);
  case 'eig'
    % calculate the eigen components based on the covariance matrix
    dataCov = cov(data);
    % when size(data,1) > size(data,2) take the left eigenvectors
    [~,dataVal,dataEig] = eig(dataCov);
    % select largest eigen variates as components
    dataComp = fliplr(dataEig(:,end-(nComp-1):end));
    % and drag the accompanying eigen values along
    dataVal = diag(dataVal)';
    dataExpl = dataVal./sum(dataVal);
    dataVal = fliplr(dataVal(:,end-(nComp-1):end));
    dataExpl = fliplr(dataExpl(:,end-(nComp-1):end));
  case {'pca','svd'}
    [dataComp,~,dataVal] = pca(data,'NumComponents',nComp);
    dataExpl = dataVal./sum(dataVal);
    dataVal = dataVal(1:nComp)';
    dataExpl = dataExpl(1:nComp)';
  case 'ica'
    % this takes a long time because the cross-correlation (covariance)
    % matrix used for the pca is nVox x nVox big
    %addpath('/Users/lennart/matlab/toolboxes/fieldtrip/external/fastica');
    %dataComp = fastica(data,'lastEig',nComp*4,'numOfIC',nComp,'g','gauss')';
    dataComp = fastica(data,'numOfIC',nComp,'g','gauss')';
    %addpath('/Users/lennart/matlab/toolboxes/fieldtrip/external/eeglab');
    %[weights,sphere] = runica(data,'pca',nComp);
    %unmixing = weights * sphere;
    %dataComp = (ummixing * data)';
end

% combine mean and components
dataComp = [dataMeanTS dataComp];

% combine and scale the eigen values (when present)
if ~isempty(dataVal)
  %dataVal = [sum(abs(dataMeanTS)) dataVal] ./ nTim;
  dataVal = [std(dataMeanTS) dataVal./nTim];
end
if ~isempty(dataExpl)
  dataExpl = [var(dataMeanTS) dataExpl];
end


% normalise the temporal variance of the components
dataComp = normalise(dataComp,1);

% save the components to text files, if requested
if ~isempty(basenameOut)

  % extract the base name for the components
  tok = regexp(basenameOut,'(.*/)(.*)','tokens','once');
  if isempty(tok), tok = {['.' filesep], basenameOut}; end
  pathOut = tok{1};
  tok = regexp(tok{2},'([^\.]*)(\.?.*)','tokens','once');
  baseOut = tok{1};

  % save the mean and components
  fnameCompOut = sprintf('%s%s_comp.txt',pathOut,baseOut);
  dlmwrite(fnameCompOut, dataComp, 'delimiter', ' ');
  
  % save the eigen values
  if ~isempty(dataVal)
    fnameCompValOut = sprintf('%s%s_compVal.txt',pathOut,baseOut);
    dlmwrite(fnameCompValOut, dataVal, 'delimiter', ' ');
  end
  
  % save the explained variance
  if ~isempty(dataExpl)
    fnameCompExplOut = sprintf('%s%s_compExpl.txt',pathOut,baseOut);
    dlmwrite(fnameCompExplOut, dataExpl, 'delimiter', ' ');
  end

end
