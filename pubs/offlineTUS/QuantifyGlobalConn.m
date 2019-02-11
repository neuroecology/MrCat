
% setup MrCat
MRCATDIR = getenv('MRCATDIR');
addpath(MRCATDIR);
setupMrCat

% specify data
%siteNameList = {'control_run1', 'control_run2', 'control_run3'};
siteNameList = {'sma_run1', 'sma_run2', 'sma_run3'};
%siteNameList = {'control', 'sma'};
% siteNameList = {'control', 'sma', 'fpc'};
%siteNameList = {'pcontrol' 'ppsma' 'pv1'};
%siteNameList = {'fpc'};
siteNameList = {'control9' 'amyg' 'pgacc'};

% specify what metrics to extract
%metricList = {'magnitude'};
%metricList = {'magnitude','extent'};
metricList = {'magnitude','extent','p95','p90','p85','p75','p50'};
metricList = {'p90'};
%metricList = {'p20'};
metricPercentileIdx = ~cellfun(@isempty,regexp(metricList,'^p[0-9]+','once'));
metricPercentileList = metricList(metricPercentileIdx);

% specify threshold of Fisher's z
thr = 0.2;

% definitions
studyDir = fullfile(filesep,'Volumes','rsfMRI','anaesthesia');
anaDir = fullfile (studyDir,'analysis');
dconnDir = fullfile (anaDir,'dconn');
workDir = fullfile(anaDir,'map');
if ~exist(workDir,'dir'), mkdir(workDir); end

% try to retrieve the dataset suffices from the config script
if exist(fullfile(anaDir,'instruct','sourceConfig.sh'),'file')
  cmd = sprintf('source %s; echo -n $suffixConn',fullfile(anaDir,'instruct','sourceConfig.sh'));
  [~,suffixConn] = unix(cmd);
else
  suffixConn = '.cleanWM';
end

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


% loop over sites
for s = 1:numel(siteNameList)
  siteName = siteNameList{s};
  fprintf('\nFUN site: %s\n',siteName);

  % open the data
  dConnFile = fullfile(dconnDir,[siteName, suffixConn, '.dconn.nii']);
  dConn = ciftiopen(dConnFile);

  % ignore negative values for the percentile metrics
  y = dConn.cdata;
  y(y<=0) = NaN;
  
  % calculate the percentile metrics
  for p = 1:numel(metricPercentileList)
    
    % extract name and percentile
    metricPercentile = metricPercentileList{p};
    prct = sscanf(metricPercentile,'p%d');
    
    % take prct-th (positive) percentile
    prctVal = prctile(y,prct,2);
    
    % save the percentile value
    templateData.cdata = prctVal;
    fName = fullfile(workDir,[siteName, suffixConn, '.' metricPercentile '.dscalar.nii']);
    ciftisave(templateData,fName,nBrainOrdinates,wb_command)
    
  end
  
  % calculate the magnitude metric
  if any(ismember({'magnitude','extent'},metricList))
    
    % take 98-th (positive) percentile as an index of the global magnitude
    prctVal = prctile(y,98,2);

    % save the percentile value
    if ismember('magnitude',metricList)
      templateData.cdata = prctVal;
      fName = fullfile(workDir,[siteName, suffixConn, '.globalMagnitude.dscalar.nii']);
      ciftisave(templateData,fName,nBrainOrdinates,wb_command)
    end
    
  end

  % calculate the extent metric
  if ismember('extent',metricList)
    
    % calculate percentage of voxels that pass the relative threshold
    y = 100*mean(bsxfun(@gt,dConn.cdata,thr*prctVal),2);

    % calculate percentage of voxels that pass the hard threshold
    %y = 100*mean(dConn.cdata>thr,2);

    % save the percentile value
    templateData.cdata = y;
    fName = fullfile(workDir,[siteName, suffixConn, '.globalExtent.dscalar.nii']);
    %fName = fullfile(workDir,[siteName, suffixConn, '.globalMean.dscalar.nii']);
    ciftisave(templateData,fName,nBrainOrdinates,wb_command)
    
  end

end
