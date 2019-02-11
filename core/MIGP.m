function dataGroup = MIGP(dataset,fileNameOut,dPCA,dPCAint,flgVarNorm,wb_command)
% Peform MIGP group-PCA as described in Smith et al. (2014) 101:738-749.
%--------------------------------------------------------------------------
%
% Use
%   MIGP({'dataset1',dataset2'},'fileNameOut',dPCA,dPCAint,flgVarNorm,'wb_command')
%
% Obligatory input:
%   dataset     cell containing strings with full input file names, which
%                can have extensions .nii.gz (NIFTI_GZ), .mat, or .nii
%                (CIFTI)
%
% Optional inputs (leave empty [] to use defaults):
%   fileNameOut: path to the output file (generally *.nii.gz or *.dtseries.nii )
%                or leave empty to return dtseries to the command-line
%   dPCA:        final number of principal components to keep in the data
%   dPCAint:     number of principal components for internal computations
%   flgVarNorm:  boolean, perform variance normalisation based on
%                stochastic noise (default: off)
%   wb_command:  path to the wb_command binary to save the output file
%
%
% Requires readimgfile.m
%
% version history
% 2018-04-15    Lennart revamped
% 2018-04-15    Lennart stored legacy version as MIGP_legacy_20170215.m
% 2017-02-15    Rogier  fixed data load function and variable
% 2016-08-25    Rogier  added data reshaping
% 2016-06-22    Rogier  bug in data reading fixed
% 2016-04-26    Rogier  changed file handling to use readimgfile
% 2016-03-08    Rogier  created
% pre-history   Steve Smith (c)
%
% copyright 2015-2018
% Lennart Verhagen, Rogier B. Mars, Steve Smith
% University of Oxford & Donders Institute
%--------------------------------------------------------------------------

% legacy detector
if nargin == 2 && ~isempty(fileNameOut)
  [~,~,ext] = fileparts(fileNameOut);
  if isempty(ext) || strcmpi(ext,'.mat')
    fprintf('\n');
    help MIGP
    error('MRCAT:MIGP:legacy','You seem to be calling MIGP.m using outdated input arguments.\nPlease update your command, or switch to the legacy version: ''MIGP_legacy_20170215.m''\n\n');
  end
end

% overhead
if nargin < 2, fileNameOut = ''; end
if nargin < 3, dPCA = []; end
if nargin < 4, dPCAint = []; end
if nargin < 5 || isempty(flgVarNorm), flgVarNorm = 0; end
if nargin < 6, wb_command = ''; end
if ~isempty(fileNameOut) && isempty(wb_command)
  % infer the location of wb_command from the .bash_profile
  [~,wb_command] = unix('cat ~/.bash_profile | grep "/workbench/" | head -1 | cut -d"=" -f2 | tr "\n" "/"');
  wb_command = fullfile(wb_command,'wb_command');
end

% set hidden flags
flgVerbose = 0;

% initialize
dataGroup = [];
nDataset = numel(dataset);

% give minimally verbose reports
fprintf('MrCat MIGP\n');
if ~flgVerbose
  nChar = 1+floor(log10(nDataset));
  cmdDel = repmat('\b',1,4+2*nChar);
  fprintf('processing dataset %*d of %d',nChar,0,nDataset);
end

% process the datasets one-by-one
for d = 1:nDataset
  % update the progress report
  if flgVerbose
    fprintf('processing dataset %d of %d',d,nDataset);
  else
    fprintf([cmdDel '%*d of %d'],nChar,d,nDataset);
  end

  % read in dtseries file
  if ~isempty(regexp(dataset{d},'\.dtseries\.nii$','match','once'))
    %data = readimgfile(dtseries);
    %data = double(data)';
    dataObj = ciftiopen(dataset{d});
  else
    % read in volumetric nifti file
    [dataObj, ~, hdr] = readimgfile(dataset{d});

    % restructure the data matrix
    dims = size(dataObj);
    nVox = prod(dims(1:end-1));
    nTim = dims(end);
    dataObj = reshape(dataObj,nVox,nTim);
  end

  % put data in required format
  if isobject(dataObj)
    data = double(dataObj.cdata)';
    dataObj.cdata = [];
  else
    data = dataObj';
    dataObj = [];
  end


  % infer number of samples and voxels/vertices
  nTim = size(data,1);
  nBrainordinates = size(data,2);

  % determine the number of components
  if d == 1
    if isempty(dPCAint) || dPCAint<1
      if ~isempty(dPCA) && dPCA>1
        dPCAint = round(6*dPCA/5);
      else
        dPCAint = round(5*nTim/8);
      end
    end
    if isempty(dPCA) || dPCA<1, dPCA = round(nTim/2); end
    if dPCAint<dPCA, dPCA = dPCAint; end
  end


  % perform variance normalisation (based on stochastic noise)
  if flgVarNorm

    % ensure each brainordinate is zero-centred over time
    data = demean(data);

    % identify structured signal+noise (first 30 principal components)
    if flgVerbose, fprintf('  isolating unstructured noise\n'); end
    nComp = 30;
    [uu,ss,vv] = ss_svds(data,nComp);

    % identify outliers to remove from signal before std calculation
    outlierThreshold = 2.3*std(vv(:));
    vv(abs(vv)<outlierThreshold) = 0;

    % remove outliers / structured noise from timeseries and ...
    % calculate standard deviation based on unstructured noise
    if flgVerbose, fprintf('  calculating variance unbiased by outliers\n'); end
    stddevs = std(data - uu*ss*vv');

    % set a lower limit before scaling
    stddevs = max(stddevs,0.001);

    % scale the data by the unstructured standard deviations
    % this is a form of variance normalisation
    if flgVerbose, fprintf('  variance normalisation\n'); end
    data = bsxfun(@rdivide,data,stddevs);

  end


  % ensure each brainordinate is zero-centred over time
  data = demean(data);

  % add the data to the group description
  dataGroup = [dataGroup; data];
  clear data;

  % principal component decomposition
  if flgVerbose, fprintf('  principal component group combination\n'); end
  [uu,~] = eigs(dataGroup*dataGroup',min(dPCAint,size(dataGroup,1)-1));
  dataGroup = uu'*dataGroup;
  clear uu;

end
% close the progress report
if ~flgVerbose
  fprintf('\n');
end

% limit the number of components to dPCA
dataGroup = dataGroup(1:dPCA,:);

% ensure each brainordinate is demeaned over time and data is upright again
dataGroup = demean(dataGroup)';
if isobject(dataObj)
  dataObj.cdata = dataGroup;
else
  dataObj = dataGroup;
end

% save the group-PCA data
if ~isempty(fileNameOut)
  fprintf('saving data\n');

  % switch depending on data type
  if isobject(dataObj)

    % save the dtseries cifti
    ciftisave(dataObj,fileNameOut,nBrainordinates,wb_command)

  else

    % place data back into original format (overwrite the input hdr.vol)
    hdr.vol = reshape(data,dims);

    % save the volumetric image
    save_nifti(hdr,fileNameOut);

  end

end
