function dataIn = rsn_cleanVariance(dataIn,fileNameOut,wb_command)
% Steve Smith's variance normalisation of unstructured noise
%
% dataIn:      path to the .nii.gz or .dtseries.nii input file or ...
%              dtseries struct with .cdata nTime x nSamples data matrix ...
%              data matrix with nTime x nSamples
% fileNameOut: path to the .nii.gz or .dtseries.nii output file or ...
%              leave empty to return dtseries/data to the command-line
% wb_command:  path to the wb_command binary to save the output file
%
%--------------------------------------------------------------------------
%
% version history
% 2018-04-15    Lennart added to MrCat and documented
% pre-history   Steve Smith (c)
%
%--------------------------------------------------------------------------

% overhead
if nargin < 2, fileNameOut = ''; end
if nargin < 3, wb_command = ''; end

% read in dtseries file
if ischar(dataIn)
  fprintf('loading data\n');
  if ~isempty(regexp(dataIn,'\.dtseries\.nii$','match','once'))
    %data = readimgfile(dtseries);
    %data = double(data)';
    dataIn = ciftiopen(dataIn);
  else
    % read in volumetric nifti file
    [dataIn, ~, hdr] = readimgfile(dataIn);

    % restructure the data matrix
    dims = size(dataIn);
    nVox = prod(dims(1:3));
    nTim = dims(4);
    dataIn = reshape(dataIn,nVox,nTim);
  end
end

% put data in required format
if isobject(dataIn)
  data = double(dataIn.cdata)';
  dataIn.cdata = [];
else
  data = dataIn';
  dataIn = [];
end

% infer number of voxels/vertices
nBrainordinates = size(data,2);

% ensure data is zero-centred over time
data = demean(data);

% identify structured signal+noise (first 30 principal components)
nComp = 30;
fprintf('principal component analysis\n');
[uu,ss,vv] = ss_svds(data,nComp);

% identify outliers to remove from signal before std calculation
outlierThreshold = 2.3*std(vv(:));
vv(abs(vv)<outlierThreshold) = 0;

% remove outliers / structured noise from timeseries and ...
% calculate standard deviation based on unstructured noise
fprintf('calculating variance unbiased by outliers\n');
stddevs = std(data - uu*ss*vv');

% set a lower limit before scaling
stddevs = max(stddevs,0.001);

% scale the data by the unstructured standard deviations
% this is a form of variance normalisation
fprintf('variance normalisation\n');
data = bsxfun(@rdivide,data,stddevs);

% ensure the data is demeaned over time and upright again
data = demean(data)';
if isobject(dataIn)
  dataIn.cdata = data;
else
  dataIn = data;
end

% save the cleaned data
if ~isempty(fileNameOut)
  fprintf('saving data\n');
  
  % switch depending on data type
  if isobject(dataIn)
    
    % infer the location of wb_command from the .bash_profile
    if isempty(wb_command)
      [~,wb_command] = unix('cat ~/.bash_profile | grep "/workbench/" | head -1 | cut -d"=" -f2 | tr "\n" "/"');
      wb_command = fullfile(wb_command,'wb_command');
    end
    
    % save the dtseries cifti
    ciftisave(dataIn,fileNameOut,nBrainordinates,wb_command)
    
  else
    
    % place data back into original format (overwrite the input hdr.vol)
    hdr.vol = reshape(data,dims);

    % save the volumetric image
    save_nifti(hdr,fileNameOut);
    
  end
  
end
