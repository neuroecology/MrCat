function dtseries = rsn_cleanVariancePca(dtseries,dPCAint,dPCA,fileNameOut,wb_command)
% a wraper around Steve Smith's variance normalisation of unstructured
% noise and principal component analysis dimensionality reduction
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

% variance normalisation
dtseries = rsn_cleanVariance(dtseries);

% dimensionality reduction
dtseries = rsn_cleanPca(dtseries,dPCAint,dPCA);

% save the cleaned data
if ~isempty(fileNameOut)
  fprintf('saving data\n');
  nVertices = size(dtseries.cdata,1);
  ciftisave(dtseries,fileNameOut,nVertices,wb_command)
end
