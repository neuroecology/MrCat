
% setup MrCat
MRCATDIR = getenv('MRCATDIR');
addpath(MRCATDIR);
setupMrCat

% settings
flgRes = false; % do not store the residuals
flgThr = 50; % threshold specified as a percentage (flgThr>=1) or hard cut-off (flgThr<1)

% definitions
studyDir = fullfile(filesep,'Volumes','rsfMRI','anaesthesia');
anaDir = fullfile (studyDir,'analysis');
dconnDir = fullfile (anaDir,'dconn');
workDir = fullfile (anaDir,'map');

% try to retrieve the dataset suffices from the config script
if exist(fullfile(anaDir,'instruct','sourceConfig.sh'),'file')
  cmd = sprintf('source %s; echo -n $suffixConn',fullfile(anaDir,'instruct','sourceConfig.sh'));
  [~,suffixConn] = unix(cmd);
else
  suffixConn = '.cleanWMCSF';
end

% specify data
siteNameA = 'control';
siteNameB = 'fpc';
dConnFileA = fullfile(dconnDir,[siteNameA, suffixConn, '.dconn.nii']);
dConnFileB = fullfile(dconnDir,[siteNameB, suffixConn, '.dconn.nii']);

% open the data
fprintf('loading data...');
dConnA = ciftiopen(dConnFileA);
dConnB = ciftiopen(dConnFileB);
fprintf(' done\n');

% initialise beta estimates
nVertices = size(dConnA.cdata,1);
betaAdd = nan(nVertices,1);
betaMult = nan(nVertices,1);
betaScale = nan(nVertices,1);
meanConn = nan(nVertices,1);
if flgRes, dConnBminA = dConnB; end

% calculate 50-th percentile
if flgThr >= 1
  fprintf('calculating thresholds...\n');
  dConnThr = dConnA.cdata + dConnB.cdata;
  %dConnThr = dConnA.cdata;
  dConnThr(dConnThr<=0) = NaN;
  thrVal = prctile(dConnThr,flgThr,2);
else
  thrVal = flgThr * ones(size(dConnA.cdata,1),1);
end

% initialise progress report
nDigit = 1+floor(log10(nVertices));
fprintf('running GLM\n  vertex: %s',repmat(' ',1,4+2*nDigit));
strFormat = [repmat('\b',1,4+2*nDigit) '%' num2str(nDigit) '.d of %' num2str(nDigit) '.d'];

% loop over rows (vertices)
for v = 1:nVertices
  % update progress report
  fprintf(strFormat,v,nVertices);

  % select data
  x = dConnA.cdata(v,:)';
  y = dConnB.cdata(v,:)';
  % take absolute
  %x = abs(x);
  %y = abs(y);
  % select strong connections
  %idx = x > 0.02;
  idx = x+y > thrVal(v);
  %idx = x > prctVal(v);
  % build a model with the mean and distribution of the control connectivity map
  xMu = mean(x(idx));
  meanConn(v) = xMu;
  X = [repmat(xMu,nVertices,1) bsxfun(@minus,x,xMu)];
  % calculate the betas using the matrix-left-divide pseudo-inverse
  b = X(idx,:) \ y(idx);
  % store the residual
  if flgRes, dConnBminA.cdata(v,:) = y - X*b; end
  % store the betas
  betaAdd(v) = b(1);
  betaMult(v) = b(2);
  % also calculate the beta while ignoring the mean (zero-centred scaling)
  betaScale(v) = x(idx)\y(idx);
end

% close progress report
fprintf('\n');

% prepare to save the data
[~,wb_command] = unix('cat ~/.bash_profile | grep "/workbench/" | head -1 | cut -d"=" -f2 | tr "\n" "/"');
wb_command = fullfile(wb_command,'wb_command');
templateFile = fullfile(MRCATDIR,'data','macaque','F99','surf','cortex_subcort.template.F99_10k.dscalar.nii');

% create the template file if it doesn't exist yet
if ~exist(templateFile,'file')
  cmd = sprintf('roiFile=$MRCATDIR/data/macaque/F99/surf/cortex_subcort.roi.F99_10k.dscalar.nii;templateFile=%s;wb_command -cifti-restrict-dense-map $roiFile COLUMN $templateFile -cifti-roi $roiFile',templateFile);
  unix(cmd);
end

% open the template file
templateData = ciftiopen(templateFile);
nBrainOrdinates = size(templateData.cdata,1);

% save the residuals
if flgRes
  fName = fullfile(workDir,[siteNameA '.' siteNameB suffixConn '.residual.dconn.nii']);
  ciftisave(dConnBminA,fName,nVertices,wb_command)
end

% save the additive beta
templateData.cdata = (betaAdd - 1) ./ meanConn;
fName = fullfile(workDir,[siteNameA '.' siteNameB suffixConn '.betaAdd.dscalar.nii']);
ciftisave(templateData,fName,nVertices,wb_command)
%unix([wb_command ' -cifti-math "(data-1)" ' fName ' -var "data" ' fName ' > /dev/null']);

% save the multiplicative beta
templateData.cdata = (betaMult - 1) ./ meanConn;
templateData.cdata = (betaMult - 1);
fName = fullfile(workDir,[siteNameA '.' siteNameB suffixConn '.betaMult.dscalar.nii']);
ciftisave(templateData,fName,nVertices,wb_command)
%unix([wb_command ' -cifti-math "(data-1)" ' fName ' -var "data" ' fName ' > /dev/null']);

% save the scaling beta
templateData.cdata = (betaScale - 1) ./ meanConn;
fName = fullfile(workDir,[siteNameA '.' siteNameB suffixConn '.betaScale.dscalar.nii']);
ciftisave(templateData,fName,nVertices,wb_command)
%unix([wb_command ' -cifti-math "(data-1)" ' fName ' -var "data" ' fName ' > /dev/null']);
