function dtseries = rsn_cleanPca(dtseries,dPCAint,dPCA,fileNameOut,wb_command)
% Principal component analysis dimensionality reduction
%
% dtseries:    path to the .dtseries.nii input file or ...
%              dtseries struct with .cdata nTime x nSamples data matrix
% dPCAint:     number of principal components for internal computations
% dPCA:        final number of principal components to keep in the data
% fileNameOut: path to the .dtseries.nii output file or ...
%              leave empty to return dtseries to the command-line
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
if nargin < 2, dPCAint = []; end
if nargin < 3, dPCA = []; end
if nargin < 4, fileNameOut = ''; end
if nargin < 5, wb_command = ''; end
if ~isempty(fileNameOut) && isempty(wb_command)
  % infer the location of wb_command from the .bash_profile
  [~,wb_command] = unix('cat ~/.bash_profile | grep "/workbench/" | head -1 | cut -d"=" -f2 | tr "\n" "/"');
  wb_command = fullfile(wb_command,'wb_command');
end

% read in dtseries file
if ischar(dtseries)
  fprintf('loading data\n');
  %data = readimgfile(dtseries);
  %data = double(data)';
  dtseries = ciftiopen(dtseries);
end

% extract data from dtseries
data = double(dtseries.cdata)';
[nTime, nVertices] = size(data);

% ensure data is zero-centred over time
data = demean(data);

% determine the number of components
if isempty(dPCAint) || dPCAint<1, dPCAint = round(3*nTime/4); end
if isempty(dPCA) || dPCA<1, dPCA = round(nTime/2); end
if dPCAint>=nTime, dPCAint = nTime-1; end
if dPCAint<dPCA, dPCA = dPCAint; end

% decompose the timeseries in principal components
fprintf('principal component analysis\n');
[uu,dd] = eigs(data*data',min(dPCAint,nTime-1));
data = uu'*data;

% store the selected principal components back in the dtseries structure
dtseries.cdata = data(1:dPCA,:)';

% save the PCA data
if ~isempty(fileNameOut)
  fprintf('saving data\n');
  ciftisave(dtseries,fileNameOut,nVertices,wb_command)
end
