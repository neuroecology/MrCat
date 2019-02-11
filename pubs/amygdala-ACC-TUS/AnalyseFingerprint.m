%------------------------------------------------------------------
% This script plots and runs statistics for connectional fingerprints and
% self-connections.
%
% To analyse the fingerprints, run this script with:
%   flgPlot = 'fingerprint';
%
% To analyse the self-connections, run this script with:
%   flgPlot = 'self';
%
% To analyse the ACC/Amyg coupling with A1, run this script with:
%   flgPlot = 'auditory';
%
% To analyse the correlation between TUS effects on ACC/Amyg and on A1:
%   flgPlot = 'auditorycorr';
%
% To analyse the group results, run this script once with:
%   flgAnaLevel = 'group';
%
% To get errorbars in the plot, run it twice in succession:
%   1. flgAnaLevel = 'subj';
%   2. flgAnaLevel = 'group';
%
% To get fingerprint statistics over the runs, run it once with:
%   flgPlot = 'fingerprint';
%   flgAnaLevel = 'sessrun';
%   flgStats = true;
%
% To get self-connection statistics over the subjects, run it once with:
%   flgPlot = 'self';
%   flgAnaLevel = 'subj';
%   flgStats = true;
%
% For fingerprints 'bilat'eral connections might give a more comprehensive
% summary, but for self-connections the 'inter'-hemispheric connections
% are most relevant. At the moment there is no script to handle the stats
% of the self-connections. When saving plots, the figures cannot be docked
% so do:
%   set(0,'DefaultFigureWindowStyle','normal');
%------------------------------------------------------------------


%-----------
%% settings
%-----------

% set the type of analysis and the analysis level
flgPlot = 'auditorycorr';    % 'fingerprint', 'self': plot either the fingerprints or the self-connections
flgAnaLevel = 'group';      % group, subj, subjrun, sess, run, sessrun
flgStats = false;           % do or do not perform stats
flgPlotFirstLevel = 'none'; % 'all','mean','none', plot all datasets of the first-level, plot the mean, or do not plot and just keep the error description to plot onto the group average
flgSave = false;            % do or do not save figures and workspace
flgSaveForRealsies = false; % yeah, do this only once, for real. This is an extra hurdle to prevent you from overwriting the most valuable figures without thinking


% pick data file names and directories
anaDir = '/Volumes/rsfMRI/anaesthesia/analysis';
if ~exist(anaDir,'dir')
  anaDir = '~/projects/lennart/fun/deepFUN/figures2';
end
workDir = fullfile(anaDir,'fingerprint',flgAnaLevel);

switch flgAnaLevel
  case 'group'
    firstLevelListAll = {''};
  case 'subj'
    firstLevelListAll = {'MK07','MK05','MK08','MK06','MK01','MK04','MK09','MK02','MK03','MK10','MK11'};
  case 'sess'
    firstLevelListAll = {'MK03.MI01087','MK02.MI01089','MK09.MI00454','MK04.MI01120','MK01.MI01082','MK06.MI01297','MK08.MI01302','MK08.MI01461','MK08.MI01615','MK05.MI01295','MK05.MI01623','MK07.MI01300','MK07.MI01465','MK07.MI01618', ...
                         'MK08.MI01754','MK05.MI01966','MK07.MI01970', ...
                         'MK10.MI02136','MK04.MI01626','MK11.MI02256','MK01.MI01827'};
  case 'run'
    firstLevelListAll = {'run1','run2','run3'};
  case 'subjrun'
    firstLevelListAll = {}; % not relevant for the deepTUS study
  case 'sessrun'
    firstLevelListAll = { 'MK03.MI01087.run1','MK02.MI01089.run1','MK09.MI00454.run1','MK04.MI01120.run1','MK01.MI01082.run1','MK06.MI01297.run1','MK08.MI01302.run1','MK08.MI01461.run1','MK08.MI01461.run2','MK08.MI01461.run3','MK08.MI01615.run1','MK08.MI01615.run2','MK08.MI01615.run3','MK05.MI01295.run1','MK05.MI01623.run1','MK05.MI01623.run2','MK05.MI01623.run3','MK07.MI01300.run1','MK07.MI01465.run1','MK07.MI01465.run2','MK07.MI01465.run3','MK07.MI01618.run1','MK07.MI01618.run2','MK07.MI01618.run3', ...
                          'MK08.MI01754.run1','MK08.MI01754.run2','MK08.MI01754.run3','MK05.MI01966.run1','MK05.MI01966.run2','MK05.MI01966.run3','MK07.MI01970.run1','MK07.MI01970.run2','MK07.MI01970.run3', ...
                          'MK10.MI02136.run1','MK10.MI02136.run2','MK10.MI02136.run3','MK04.MI01626.run1','MK04.MI01626.run2','MK04.MI01626.run3','MK11.MI02256.run1','MK11.MI02256.run2','MK11.MI02256.run3','MK01.MI01827.run1','MK01.MI01827.run2','MK01.MI01827.run3'};

end
nFirstLevelAll = numel(firstLevelListAll);

% prepad with a period, if not already done so
firstLevelListAll = cellfun(@(x) strcat(repmat('.',1,(~isempty(x) && isempty(regexp(x,'^\..*','once')))),x),firstLevelListAll,'UniformOutput',false);

% specify the acquisition time
flgTimeContrast = 'seedsite'; % constrast either 'seed', 'site', or 'seedsite'
acquisitionTimeList = {};

% set from which hemisphere to draw or combine the connectivity
% flgCombineHemi          % 'left', 'right': left or right inter-hemispheric connectivity
                          % 'inter': average of inter-hemispheric connectivity
                          % 'bilat': the average of the bilateral connectivity
% set the hemisphere combination flag based on the type of plot
switch flgPlot
  case {'fingerprint','time','auditorycorr'}
    flgCombineHemi = 'bilat';
  case 'self'
    flgCombineHemi = 'inter';
end
flgScaleErr = true;       % scale the error term with respect to the effect size, this only makes sense to represent error terms from one dataset onto another
flgErrDescrip = 'sem';    % how to describe the error, as 'sem' or 'range'
flgCapZstat = true;       % cap z-stats between [-2 2] (a sensible idea) or do not limit the stat
flgPlotFingerprintSelf = 'ignore'; % 'exclude' (dmFC study), 'ignore' (deepTUS study), or 'include'

% NaNs are not allowed for stats
if flgStats && strcmpi(flgPlotFingerprintSelf,'ignore')
  flgPlotFingerprintSelf = 'exclude';
end
% set number of permutations for the fingerprint
nPerm = inf;
if nFirstLevelAll > 25, nPerm = 100000; end

% adjust the workDir
if ~flgCapZstat
  workDir = fullfile(fileparts(workDir),'noCap','median');
end

% set figure directory
if (strcmpi(flgAnaLevel,'run') && numel(firstLevelListAll)==1) || strcmpi(flgPlot,'time') || strcmpi(flgPlot,'auditorycorr')
  figDir = '~/projects/lennart/fun/deepFUN/figures2/figS3';
else
  figDir = '~/projects/lennart/fun/deepFUN/figures2/fig3';
end
if ~exist(figDir,'dir'), mkdir(figDir); end

%set(0,'DefaultFigureWindowStyle','docked')
set(0,'DefaultFigureWindowStyle','normal')



%---------------
%% load targets
%---------------

% load the instruction file containing the fingerprint site, seed, and targets
instructFile = fullfile(anaDir,'instruct','AccAmyg','instructExtractFingerprint.txt');
if exist(instructFile,'file')
  fingerprintList = regexp(importdata(instructFile),' ','split');
else
  load('~/projects/lennart/fun/deepFUN/figures2/fig3/workspace_group_fingerprint.mat','fingerprintList');
end

% extract fingerprint site, seed, targets, and first-level conditions
nFingerprint = numel(fingerprintList);
siteList = unique(cellfun(@(x) x{1},fingerprintList,'UniformOutput',false));
nSite = numel(siteList);
seedList = unique(cellfun(@(x) x{2},fingerprintList,'UniformOutput',false));
nSeed = numel(seedList);

% ignore the large area 11 ROI (used as a control)
for f = 1:nFingerprint
  fingerprintList{f} = fingerprintList{f}(~ismember(fingerprintList{f},'11Big'));
end

% re-order the seeds and sites
prefOrder = {'control','control9','sma','psma','fpc','pgacc','amyg','lofc','midsts','pcontrol','ppsma','pv1','A1'};
[~,idxPrefOrder] = ismember(prefOrder,siteList);
idxPrefOrder = idxPrefOrder(idxPrefOrder>0);
siteList = siteList(idxPrefOrder);
[~,idxPrefOrder] = ismember(prefOrder,seedList);
idxPrefOrder = idxPrefOrder(idxPrefOrder>0);
seedList = seedList(idxPrefOrder);

% switch between plotting the fingerprint and self-connection
switch flgPlot
  case {'fingerprint','time','auditorycorr'}
    % include or exclude self projections
    if strcmpi(flgPlotFingerprintSelf,'exclude')
      for f = 1:nFingerprint
        %fingerprintList{f} = [fingerprintList{f}(1:2) setdiff(fingerprintList{f}(3:end),fingerprintList{f}(2),'stable')];
        % exclude self AND auditory targets
        fingerprintList{f} = [fingerprintList{f}(1:2) setdiff(fingerprintList{f}(3:end),[fingerprintList{f}(2) 'A1'],'stable')];
      end
    else
      % ignore only auditory targets
      for f = 1:nFingerprint
        fingerprintList{f} = [fingerprintList{f}(1:2) setdiff(fingerprintList{f}(3:end),'A1','stable')];
      end
    end
  case 'self'
    flgPlotFingerprintSelf = 'include';
    % keep only the self projections
    for f = 1:nFingerprint
      fingerprintList{f} = fingerprintList{f}([1 2 2]);
    end
end

% please note:
%   all sites must have the same seeds
% 	each seed must have the same targets across the sites
% 	targets can be different across seeds
%   when extracting first-level fingerprints, all seeds/sites must have
%     the same first-level conditions

% initialise the fingerprint data structure
% fingerprint{nSeed}[nTarget x nSite]
fingerprint = cell(1,nSeed);
targetList = cell(1,nSeed);
targetTableList = cell(1,nSeed);
for s = 1:nSeed
  % extract the targetList
  idx = find(cellfun(@(x) strcmpi(x{2},seedList{s}),fingerprintList),1,'first');
  targetList{s} = fingerprintList{idx}(3:end);
  % initialise the data structure
  nTarget = numel(targetList{s});
  fingerprint{s} = nan(nTarget,nSite,nFirstLevelAll);
end


%----------------
%% retrieve data
%----------------

% loop over FUN sites
for ss = 1:nSite
  siteName = siteList{ss};

  % limit the full list of first-levels to those available for this site
  firstLevelList = {};
  for fl = 1:nFirstLevelAll

    % define fingerprint data file
    fingerprintFile = fullfile(workDir,[siteName firstLevelListAll{fl} '.txt']);

    % test if this file exists or not
    if exist(fingerprintFile,'file')
      firstLevelList{end+1} = fingerprintFile;
    end

  end
  nFirstLevel = numel(firstLevelList);

  % loop over first-level conditions (empty when group-level analysis)
  for fl = 1:nFirstLevel

    % read in the fingerprint text file
    T = readtable(firstLevelList{fl},'ReadVariableNames',false,'ReadRowNames',true);

    % extract the seed-specific target names
    idxTargetNames = ~cellfun(@isempty,regexp(T.Properties.RowNames,'.*seed$','once'));
    seedTargetNames = [T.Properties.RowNames(idxTargetNames) T(idxTargetNames,:).Variables];

    % drop the 'seed' text rows from the table
    T = T(~idxTargetNames,:);

    % convert cell character to double
    for idx = 1:width(T)
      if iscell(T.(idx)), T.(idx) = str2double(T.(idx)); end
    end

    % loop over seeds
    for s = 1:nSeed

      % select the appropriate fingerprint
      seedName = seedList{s};
      f = find(cellfun(@(x) strcmpi(x{1},siteName) && strcmpi(x{2},seedName),fingerprintList),1,'first');

      switch flgCombineHemi
        case 'inter'
          % select data lines matching this seed
          [~,idxSeedLeft] = ismember([seedName '_left'],T.Properties.RowNames);
          [~,idxSeedRight] = ismember([seedName '_right'],T.Properties.RowNames);
          % select relevant targets
          idxTargetNames = ~cellfun(@isempty,regexp(seedTargetNames(:,1),['^' seedName '_seed$'],'once'));
          variableNames = seedTargetNames(idxTargetNames,2:end);
          targetListLeft = cellfun(@(x) [x '.left'],targetList{s},'UniformOutput',false);
          targetListRight = cellfun(@(x) [x '.right'],targetList{s},'UniformOutput',false);
          [~,idxSelectLeft] = ismember(targetListLeft,variableNames);
          [~,idxSelectRight] = ismember(targetListRight,variableNames);
          % restrict the table to the selection
          Tleft = T(idxSeedLeft,idxSelectLeft);
          Tright = T(idxSeedRight,idxSelectRight);
          % average left and right, store in structure
          fingerprint{s}(:,ss,fl) = ((Tleft.Variables + Tright.Variables) / 2)';

        otherwise
          % extract bilateral connectivity
          [~,idxSeed] = ismember([seedName '_' flgCombineHemi],T.Properties.RowNames);
          targetListHemi = cellfun(@(x) [x '.' flgCombineHemi],targetList{s},'UniformOutput',false);
          idxTargetNames = ~cellfun(@isempty,regexp(seedTargetNames(:,1),['^' seedName '_seed$'],'once'));
          variableNames = seedTargetNames(idxTargetNames,2:end);
          [~,idxTarget] = ismember(targetListHemi,variableNames);
          fingerprint{s}(:,ss,fl) = T(idxSeed,idxTarget).Variables';
      end

    end

  end

end


%---------
%% rename
%---------

% rename sites, seeds, and targets
renameList = {'control9','control'
              'pgacc','ACC'
              'amyg','amygdala'
              'sma','SMA'
              'fpc','FPC'
              'midsts','midSTS'
              'M1lat','M1'
              'M1med','M1'
              'lofcChau','47-12o'
              '9mc','9m'
              'strm','striatum'};
for r = 1:size(renameList,1)
  % rename sites
  idx = ismember(siteList,renameList{r,1});
  if any(idx), siteList{idx} = renameList{r,2}; end
  % rename seeds
  idx = ismember(seedList,renameList{r,1});
  if any(idx), seedList{idx} = renameList{r,2}; end
  % rename targets
  for s = 1:nSeed
    idx = ismember(targetList{s},renameList{r,1});
    if any(idx), targetList{s}{idx} = renameList{r,2}; end
  end
end


% average across the first level
if strcmpi(flgPlotFirstLevel,'all'), clear fingerprintErr; end
if nFirstLevelAll > 1 && ~strcmpi(flgPlotFirstLevel,'all')
  fingerprintAll = fingerprint;
  fingerprintErr = cell(1,2);
  for s = 1:nSeed
    fingerprint{s} = nanmean(fingerprintAll{s},3);
    switch flgErrDescrip
      case 'range', fingerprintErr{s} = bsxfun(@minus,cat(4,min(fingerprintAll{s},[],3),max(fingerprintAll{s},[],3)),fingerprint{s});
      otherwise, fingerprintErr{s} = nansem(fingerprintAll{s},0,3);
    end
    % rescale with respect to a robust maximum of the mean fingerprint
    if flgScaleErr
      maxMagn = sort(fingerprint{s},1,'descend');
      if nTarget > 3
        maxMagn = mean(maxMagn(1:3,:),1);
      else
        maxMagn = mean(maxMagn,1);
      end
      fingerprintErr{s} = bsxfun(@rdivide,fingerprintErr{s},maxMagn);
    end
  end
  % continue to plot the mean over the first-level, or stop here
  if strcmpi(flgPlotFirstLevel,'mean')
    nFirstLevelAll = 1;
  else
    % do not plot the mean but jump straight to the stats
    flgPlot = [flgPlot ' doNotPlot'];
  end
elseif exist('fingerprintErr','var') && flgScaleErr
  for s = 1:nSeed
    % rescale with respect to a robust maximum of the mean fingerprint
    maxMagn = sort(fingerprint{s},1,'descend');
    if nTarget > 3
      maxMagn = mean(maxMagn(1:3,:),1);
    else
      maxMagn = mean(maxMagn,1);
    end
    fingerprintErr{s} = bsxfun(@times,fingerprintErr{s},maxMagn);
  end
end

% ignore self-projections by replacing with NaN, or not
if strcmpi(flgPlotFingerprintSelf,'ignore')

  % loop over seeds
  for s = 1:nSeed
    idxSelf = ismember(targetList{s},seedList{s});
    if ~any(idxSelf), continue; end
    targetList{s}{idxSelf} = '';
    fingerprint{s}(idxSelf,:,:) = NaN;
    if exist('fingerprintAll','var')
      fingerprintAll{s}(idxSelf,:,:) = NaN;
    end
    if exist('fingerprintErr','var')
      fingerprintErr{s}(idxSelf,:,:) = NaN;
    end
  end

end


%---------
%% plot
%---------

% plot depending on data type
switch flgPlot
  case 'fingerprint'

    % initialise a full-screen figure when plotting all conditions on the
    % 'subj' or 'run' first level
    if strcmpi(flgPlotFirstLevel,'all') && ismember(flgAnaLevel,{'subj','run'})
      hff = figure('Color','w','units','normalized','outerposition',[0 0 1 1]);
      flgFigure = false;
      p = 0;
    else
      flgFigure = true;
    end

    % plot and save the fingerprints
    figHandle = cell(nSeed,nFirstLevelAll);
    for s = 1:nSeed
      range = [];
      switch seedList{s}
        case {'amygdala','amyg'}, range = [-0.2 0.3]; NrTickMarks = 5;
        case {'ACC','pgacc','A1'}, range = [-0.2 0.6]; NrTickMarks = 4;
        case 'SMA', range = [-0.4 0.6]; NrTickMarks = 5;
        case 'FPC', range = [-0.4 0.6]; NrTickMarks = 5;
      end

      % HACK: overwrite range
      if nFirstLevelAll > 1, range = [-0.5 0.75]; NrTickMarks = 5; end
      if nFirstLevelAll > 3, range = [-0.6 1.2]; NrTickMarks = 4; end

      % loop over conditions within the analysis level
      for fl = 1:nFirstLevelAll

        % set the name of the first level conditions
        firstLevelName = firstLevelListAll{fl};

        % define the title
        titleStr = [seedList{s} ' fingerprint'];
        if nFirstLevelAll > 1, titleStr = sprintf('%s\n%s: %s',titleStr,flgAnaLevel,firstLevelName); end

        % initialise a figure
        if flgFigure
          hf = figure('Color','w','Position',[400 400 800 600]);

          % set correct printing properties
          hf.PaperType = '<custom>';
          %set(h,'PaperUnits','centimeters');
          if strcmpi(hf.PaperUnits,'centimeters')
            hf.PaperSize = [30 25];
            hf.PaperPosition = [0 0 30 25];
          elseif strcmpi(hf.PaperUnits,'inches')
            hf.PaperSize = [12 10];
            hf.PaperPosition = [0 0 12 10];
          end
          hf.PaperPositionMode = 'auto';

        else

          % initialise a subplot instead
          p = p + 1;
          hf = subplot(nSeed,nFirstLevelAll,p);

        end

        % draw the spider plot
        if exist('fingerprintErr','var')
          err = squeeze(fingerprintErr{s}(:,:,fl,:));
          hS = spider_wedge(fingerprint{s}(:,:,fl),err,'Handle',hf,'PlotType','line','PlotTypeErr','cloud','AlphaErr',0.2,'LineWidth',4,'Scale','none','Title','','Label',targetList{s},'Legend',siteList,'Range',range,'NrTickMarks',NrTickMarks,'Web',true,'RefLine',0,'ReturnAllHandles',true);
        else
          hS = spider_wedge(fingerprint{s}(:,:,fl),'Handle',hf,'PlotType','line','PlotTypeErr','cloud','LineWidth',4,'Scale','none','Title','','Label',targetList{s},'Legend',siteList,'Range',range,'NrTickMarks',NrTickMarks,'Web',true,'RefLine',0,'ReturnAllHandles',true);
        end

        % do not polish subplots
        if ~flgFigure
          hS.title = title(titleStr);
          hS.title.Visible = 'on';
          if p < nSeed * nFirstLevelAll
            delete(hS.legend);
          else
            hS.legend.Location = 'best';
            hlPos = hS.legend.Position;
            hlPos(1) = 1/2;
            hlPos(2) = 1/2;
            hS.legend.Position = hlPos;
          end
          continue
        end

        % adjust plot (axis)
        haPos = hS.axis.Position;
        haPos(2) = haPos(2)/2;
        hS.axis.Position = haPos;
        hS.axis.Color = [1 1 1];
        hS.axis.XColor = [1 1 1];
        hS.axis.YColor = [1 1 1];
        hS.axis.FontSize = 24;

        % targets
        for t = 1:numel(hS.spokes)
          hS.spokes{t}.FontSize = 20;
        end

        % tick labels
        for t = 1:numel(hS.tickMarks)
          hS.tickMarks{t}.FontSize = 12;
        end

        % add title
        hS.title = text(0,1.4,titleStr,'HorizontalAlignment','center','FontSize',28,'FontWeight','normal','Color','k');
        hS.title.Visible = 'on';

        % legend
        hS.legend.Title.String = 'FUN';
        hS.legend.FontSize = 20;
        hS.legend.Title.FontSize = 24;
        hS.legend.Title.FontWeight = 'normal';
        hS.legend.Box = 'off';
        hS.legend.Location = 'northeast';
        hlPos = hS.legend.Position;
        hlPos(1) = 2/3;
        hlPos(2) = 7/10;
        hS.legend.Position = hlPos;

        % prepad with an underscore, if not already done so
        if ~isempty(firstLevelName) && isempty(regexp(firstLevelName,'^_.*','once'))
          firstLevelName = ['_' firstLevelName];
        end

        % store the figure handle in a cell structure for later use
        figHandle{s,fl} = hS.figure;

        % save figures
        if flgSave
          % save as png
          figName = fullfile(figDir,['fingerprint_' seedList{s} firstLevelName]);
          export_fig([figName '.png'],'-png','-r600','-nocrop',hS.figure);

          % save the figure as pdf without the legend and title
          hS.legend.Visible = 'off';
          hS.title.Visible = 'off';
          export_fig([figName '_flat.pdf'],'-pdf','-r600','-nocrop',hS.figure);
          if flgSaveForRealsies
            print([figName '.pdf'], '-dpdf', '-r600', hS.figure);
          end
          hS.legend.Visible = 'on';
          hS.title.Visible = 'on';
        end

      end

    end


  case 'self'

    % restructure the fingerprint into a matrix
    dat = vertcat(fingerprint{:});
    if exist('fingerprintErr','var')
      err = vertcat(fingerprintErr{:});
    else
      err = 0.*dat;
    end

    % concatenate horizontally, when only one site is available
    %if nSite==1 && nFirstLevelAll==1
    %  dat = dat';
    %  err = err';
    %end

    % ignore the control condition
    %idxIncl = ~ismember(siteList,'control');
    %siteList = siteList(idxIncl);
    %dat = dat(idxIncl,:);
    %err = err(idxIncl,:);

    % specify y-range
    switch flgAnaLevel
      case 'group'
        if flgCapZstat, yLimits = [1.3 1.7]; else, yLimits = [1.5 2]; end
      otherwise
        if flgCapZstat, yLimits = [1.1 1.4]; else, yLimits = [0 5]; end
    end

    % initialise a figure
    hf = figure('Color','w','Position',[400 400 800 800]);

    % set correct printing properties
    hf.PaperType = '<custom>';
    %set(h,'PaperUnits','centimeters');
    if strcmpi(hf.PaperUnits,'centimeters')
      hf.PaperSize = [30 30];
      hf.PaperPosition = [0 0 30 30];
    elseif strcmpi(hf.PaperUnits,'inches')
      hf.PaperSize = [12 12];
      hf.PaperPosition = [0 0 12 12];
    end
    hf.PaperPositionMode = 'auto';

    % draw a bar plot of the self-connection barplot
    hb = bar(dat,'LineStyle','none');
    ha = gca;

    % set colour of the bars
    col = get(ha,'colororder');
    idxCol = rem(1:nSite,size(col,1)); idxCol(idxCol==0) = size(col,1);
    col = col(idxCol,:);
    for d = 1:nSite
      hb(d).FaceColor = col(d,:);
    end

    % get x positions of bar graph
    x = getbarx(hb);
    if nSite==1, x = x'; end

    % add errorbars, loop over first data dimension
    hold on;
    for d = 1:nSite
      errorbar(x(:,d),dat(:,d),err(:,d),'LineStyle','none','Color','k','LineWidth',2);
    end
    hold off;

    % adjust plot (axis)
    ha.Position = [0.2 0.2 0.7 0.6];
    ha.XLim = [0.4 2.6];
    ha.Box = 'off';
    ha.Color = 'w';
    ha.XColor = 'k';
    ha.YColor = 'k';
    ha.LineWidth = 1.5;
    ha.FontSize = 24;

    % add title
    ht = title(ha,'strength of self-connections');
    ht.Units = 'normalized';
    ht.Position = [0.5 1.15 0];
    ht.Color = 'k';
    ht.FontSize = 32;
    ht.FontWeight = 'normal';

    % add legend
    hl = legend(siteList,'Location','north','Box','off');
    hl.Title.String = 'FUN';
    hl.TextColor = 'k';
    hl.Title.Color = 'k';
    hl.Title.FontSize = 28;
    hl.Title.FontWeight = 'normal';
    hlPos = hl.Position;
    hlPos(1) = 1/2;
    hlPos(2) = 2/3;
    hl.Position = hlPos;

    % add axis labels
    ha.XLim = [0.4 2.6];
    xlabel('connectivity seed','FontSize',28);
    ha.XLabel.Units = 'normalized';
    ha.XLabel.Position = [0.5 -0.12 0];
    ha.XTickLabel = seedList;
    ylabel('self connection (Fisher''s z)','FontSize',28);
    ha.YLim = yLimits;
    if ~strcmpi(flgAnaLevel,'group') && ~flgCapZstat
      ha.YTick = ha.YLim(1):1:ha.YLim(2);
    else
      ha.YTick = ha.YLim(1):0.1:ha.YLim(2);
    end
    ha.YLabel.Units = 'normalized';
    ha.YLabel.Position = [-0.12 0.5 0];

    % save figures
    if flgSave
      % save as png
      figName = fullfile(figDir,'selfConn');
      export_fig([figName '.png'], '-png','-r600','-nocrop', hf);

      % save the figure as pdf without the legend and title
      hl.Visible = 'off';
      ht.Visible = 'off';
      export_fig([figName '_flat.pdf'], '-pdf','-r600','-nocrop', hf);
      if flgSaveForRealsies
        print([figName '.pdf'], '-dpdf', '-r600', hf);
      end
      hl.Visible = 'on';
      ht.Visible = 'on';
    end


  case 'auditorycorr'

    % prepare a figure
    hf = figure('Color','w');
    nPlot = nSite * nSeed;
    c = 0;

    % loop over sites
    for ss = nSite:-1:1
      switch flgAnaLevel
        case 'group', idxTUSeffect = sort(setdiff(1:nSite,ss),'ascend');
        otherwise, idxTUSeffect = sort(setdiff(1:nSite,ss),'descend');
      end

      % loop over seeds
      for s = nSeed:-1:1
        idxSeedComp = sort(setdiff(1:nSeed,s),'descend');
        c = c + 1;

        switch flgAnaLevel
          case 'group'

            % remove NaNs across seeds to compare
            idxNan = any(isnan(cat(2,fingerprint{idxSeedComp})),2);

            % extract TUS effect for each seed to compare
            A = diff(fingerprint{idxSeedComp(1)}(~idxNan,idxTUSeffect),1,2);
            % A = A - mean(A);
            B = diff(fingerprint{idxSeedComp(2)}(~idxNan,idxTUSeffect),1,2);
            % B = B - mean(B);

            % correlate TUS effect between seeds
            [r, p] = corr(A,B);

            % draw scatter plot with a linear fit
            f = fit(A,B,'poly1');
            subplot(nSite,nSeed,c);
            hp = plot(f,A,B);
            legend('off');
            ha = gca;
            ha.XLabel.String = ['seed 1: ' seedList{idxSeedComp(1)}];
            ha.YLabel.String = ['seed 2: ' seedList{idxSeedComp(2)}];
            ht = title(sprintf('TUS effect: %s - %s',siteList{idxTUSeffect}));
            text(0.05,0.95,sprintf('r = %.4f\np = %.4f',r,p),'Units','normalized','HorizontalAlignment','left','VerticalAlignment','top');

            % report
            fprintf('\nTUS effect (%s - %s), comparing seeds (%s - %s):\n  r = %.4f\n  p = %.4f\n\n',siteList{idxTUSeffect},seedList{idxSeedComp},r,p);

            % now make the two prti

          otherwise

            % This is not a really valid approach... I kinda forgot this
            % was a between subject design, so there isn't a
            % straightforward way of contrasting two sites within one
            % subject. I think it would be best to stick to the group
            % analysis. Code is kept here to archive, but one should not
            % trust the outcome.

            % identify NaNs across seeds to compare
            idxNan = any(isnan(cat(2,fingerprint{idxSeedComp})),2);

            % loop over seeds
            d = nan(size(Adat,2),2);
            for sc = 1:2

              % extract first-level fingerprints of site 1
              Adat = squeeze(fingerprintAll{idxSeedComp(sc)}(~idxNan,idxTUSeffect(1),:));

              % ignore entries without data
              Adat = Adat(:,~all(isnan(Adat),1));

              % compare each first-level of site 1 against the mean of site 2
              Aref = fingerprint{idxSeedComp(sc)}(~idxNan,idxTUSeffect(2));

              % calculate the cosine similarity for each first-level entry
              for fl = 1:size(Adat,2)
                d(fl,sc) = cosine_similarity(Adat(:,fl),Aref);
              end

            end

            % correlate TUS effect between seeds
            [r, p] = corr(d(:,1),d(:,2));

            % draw scatter plot with a linear fit
            f = fit(d(:,1),d(:,2),'poly1');
            subplot(nSite,nSeed,c);
            hp = plot(f,d(:,1),d(:,2));
            legend('off');
            ha = gca;
            ha.XLabel.String = ['seed 1: ' seedList{idxSeedComp(1)}];
            ha.YLabel.String = ['seed 2: ' seedList{idxSeedComp(2)}];
            ht = title(sprintf('TUS effect: %s - %s',siteList{idxTUSeffect}));
            text(0.05,0.95,sprintf('r = %.4f\np = %.4f',r,p),'Units','normalized','HorizontalAlignment','left','VerticalAlignment','top');

            % report
            fprintf('\nTUS effect (%s - %s), comparing seeds (%s - %s):\n  r = %.4f\n  p = %.4f\n\n',siteList{idxTUSeffect},seedList{idxSeedComp},r,p);

        end

      end

    end

    % now make the pretty plots to save
    if strcmpi(flgAnaLevel,'group')

      % initialise a figure
      hf = figure('Color','w','Position',[400 400 800 800]);

      % set correct printing properties
      hf.PaperType = '<custom>';
      %set(h,'PaperUnits','centimeters');
      if strcmpi(hf.PaperUnits,'centimeters')
        hf.PaperSize = [30 30];
        hf.PaperPosition = [0 0 30 30];
      elseif strcmpi(hf.PaperUnits,'inches')
        hf.PaperSize = [12 12];
        hf.PaperPosition = [0 0 12 12];
      end
      hf.PaperPositionMode = 'auto';


      % loop over ACC and amygdala
      plotSiteList = {'ACC','amygdala'};
      hp = cell(1,2);
      for pc = 1:numel(plotSiteList)
        plotSite = plotSiteList{pc};

        % select the site-relevant data
        switch plotSite
          case 'ACC'
            idxTUSeffect = [1 2];
            idxSeedComp = [3 1];
          case 'amygdala'
            idxTUSeffect = [1 3];
            idxSeedComp = [3 2];
        end

        % remove NaNs across seeds to compare
        idxNan = any(isnan(cat(2,fingerprint{idxSeedComp})),2);

        % extract TUS effect for each seed to compare
        A = diff(fingerprint{idxSeedComp(1)}(~idxNan,idxTUSeffect),1,2);
        % A = A - mean(A);
        B = diff(fingerprint{idxSeedComp(2)}(~idxNan,idxTUSeffect),1,2);
        % B = B - mean(B);

        % correlate TUS effect between seeds
        [r, p] = corr(A,B);

        % draw scatter plot with a linear fit
        f = fit(A,B,'poly1');
        hp{pc} = plot(f,A,B);

        % switch depending on plot
        if pc == 1
          ha = gca;
          col = ha.ColorOrder;
          hold on;
        else
          hold off;
        end

        % set properties of the data points
        hp{pc}(1).Marker = 'o';
        hp{pc}(1).MarkerSize = 12;
        hp{pc}(1).Color = col(1+pc,:);
        hp{pc}(1).MarkerFaceColor = col(1+pc,:);

        % set properties of the line
        hp{pc}(2).Color = col(1+pc,:);
        hp{pc}(2).LineStyle = '-';
        hp{pc}(2).LineWidth = 3;

      end

      % remove legend
      legend('off');

      % adjust plot (axis)
      ha.Position = [0.2 0.2 0.7 0.7];
      ha.Box = 'off';
      ha.Color = 'w';
      ha.XColor = 'k';
      ha.YColor = 'k';
      ha.LineWidth = 1.5;
      ha.FontSize = 24;

      % add axis labels
      ha.XLim = [-0.2 0.1];
      ha.XTick = -0.2:0.1:0.1;
      ha.XLabel.String = 'TUS effect on auditory cortex (z)';
      ha.XLabel.FontSize = 28;
      ha.XLabel.Units = 'normalized';
      ha.XLabel.Position = [0.5 -0.12 0];
      ha.YLim = [-0.3 0.1];
      ha.YTick = -0.3:0.1:0.1;
      ha.YLabel.String = 'TUS effect on stimulation site (z)';
      ha.YLabel.Units = 'normalized';
      ha.YLabel.Position = [-0.12 0.5 0];

      % save figures
      if flgSave
        % save as png
        figName = fullfile(figDir,'auditoryCorr');
        export_fig([figName '.png'], '-png','-r600','-nocrop', hf);

        % save the figure as pdf without the legend and title
        export_fig([figName '_flat.pdf'], '-pdf','-r600','-nocrop', hf);
        if flgSaveForRealsies
          print([figName '.pdf'], '-dpdf', '-r600', hf);
        end
      end

    end

  case 'time'

    % extract data, contrasting either FUN sites or connectivity seeds
    switch flgTimeContrast
      case 'site'

        % only consider the SMA connectivity seed (for both SMA and FPC FUN)
        s = 1;
        d = nan(size(fingerprintAll{1},3),nSite-1);
        t = d;

        % loop over FUN sites
        for f = 1:nSite

          % skip the control site (i.e. SMA vs. FPC comparison)
          if strcmpi(siteList{f},'control'), continue; end

          % select a subset of the FUN sites to compare
          idxSite = setdiff(1:nSite,f);

          % assign to first "same" or second "diff" data matrices
          if strcmpi(seedList{s},siteList{idxSite(2)}), idxData = 1; else, idxData = 2; end

          % specify data
          a = squeeze(fingerprintAll{s}(:,idxSite(1),:));
          b = squeeze(fingerprintAll{s}(:,idxSite(2),:));

          % compare against the subject mean of the controls
          %a = [repmat(mean(a(:,1:3),2),1,3) repmat(mean(a(:,4:6),2),1,3) repmat(mean(a(:,7:9),2),1,3)];
          %a = [repmat(mean(a(:,1:3:9),2),1,3) repmat(mean(a(:,2:3:9),2),1,3) repmat(mean(a(:,3:3:9),2),1,3)];
          %a = repmat(mean(a,2),1,9);

          % loop over first level
          for fl = 1:size(a,2)

            % calculate distance
            d(fl,idxData) = cosine_similarity(a(:,fl),b(:,fl));

            % retrieve time
            idx = ismember(acquisitionTimeList(:,1),lower([siteList{idxSite(2)} '.' firstLevelList{fl}]));
            t(fl,idxData) = acquisitionTimeList{idx,2};

          end

        end

      case 'seed'

        % only consider the SMA FUN site (over both SMA and FPC seeds)
        idxSite = [1 2];
        d = nan(size(fingerprintAll{1},3),nSeed);
        t = d;

        % loop over connectivity seeds
        for s = 1:nSeed

          % assign to first "same" or second "diff" data matrices
          if strcmpi(seedList{s},siteList{idxSite(2)}), idxData = 1; else, idxData = 2; end

          % specify data
          a = squeeze(fingerprintAll{s}(:,idxSite(1),:));
          b = squeeze(fingerprintAll{s}(:,idxSite(2),:));

          % compare against the subject mean of the controls
          %a = [repmat(mean(a(:,1:3),2),1,3) repmat(mean(a(:,4:6),2),1,3) repmat(mean(a(:,7:9),2),1,3)];
          %a = [repmat(mean(a(:,1:3:9),2),1,3) repmat(mean(a(:,2:3:9),2),1,3) repmat(mean(a(:,3:3:9),2),1,3)];
          %a = repmat(mean(a,2),1,9);

          % loop over first level
          for fl = 1:size(a,2)

            % calculate distance
            d(fl,idxData) = cosine_similarity(a(:,fl),b(:,fl));

            % retrieve time
            idx = ismember(acquisitionTimeList(:,1),lower([siteList{idxSite(2)} '.' firstLevelList{fl}]));
            t(fl,idxData) = acquisitionTimeList{idx,2};

          end

        end

      case 'seedsite'

        % only consider the SMA FUN site (over both SMA and FPC seeds)
        idxSite = [1 2; 1 3];
        d = nan(size(fingerprintAll{1},3),nSeed,size(idxSite,1));
        t = d;

        % loop over connectivity seeds
        for s = 1:nSeed

          % loop over FUN sites
          for f = 1:size(idxSite,1)

            % assign to first "same" or second "diff" data matrices
            if strcmpi(seedList{s},siteList{idxSite(f,2)}), idxData = 1; else, idxData = 2; end

            % specify data
            a = squeeze(fingerprintAll{s}(:,idxSite(f,1),:));
            b = squeeze(fingerprintAll{s}(:,idxSite(f,2),:));

            % compare against the subject mean of the controls
            %a = [repmat(mean(a(:,1:3),2),1,3) repmat(mean(a(:,4:6),2),1,3) repmat(mean(a(:,7:9),2),1,3)];
            %a = [repmat(mean(a(:,1:3:9),2),1,3) repmat(mean(a(:,2:3:9),2),1,3) repmat(mean(a(:,3:3:9),2),1,3)];
            %a = repmat(mean(a,2),1,9);

            % loop over first level
            for fl = 1:size(a,2)

              % calculate distance
              d(fl,s,idxData) = cosine_similarity(a(:,fl),b(:,fl));

              % retrieve time
              idx = ismember(acquisitionTimeList(:,1),lower([siteList{idxSite(f,2)} '.' firstLevelList{fl}]));
              t(fl,s,idxData) = acquisitionTimeList{idx,2};

            end

          end

        end

        % reshape the d an t matrices to 2*samples x same/diff size
        d = reshape(d,size(fingerprintAll{1},3)*nSeed,size(idxSite,1));
        t = reshape(t,size(fingerprintAll{1},3)*nSeed,size(idxSite,1));


      case 'effective'

        % only consider the SMA FUN site (over both SMA and FPC seeds)
        idxSite = [1 2; 1 3];
        d = nan(size(fingerprintAll{1},3),size(idxSite,1));
        t = d;

        % loop over FUN sites
        for f = 1:size(idxSite,1)

          % specify data
          a = squeeze(fingerprintAll{f}(:,idxSite(f,1),:));
          b = squeeze(fingerprintAll{f}(:,idxSite(f,2),:));

          % compare against the subject mean of the controls
          %a = [repmat(mean(a(:,1:3),2),1,3) repmat(mean(a(:,4:6),2),1,3) repmat(mean(a(:,7:9),2),1,3)];
          %a = [repmat(mean(a(:,1:3:9),2),1,3) repmat(mean(a(:,2:3:9),2),1,3) repmat(mean(a(:,3:3:9),2),1,3)];
          %a = repmat(mean(a,2),1,9);

          % loop over first level
          for fl = 1:size(a,2)

            % calculate distance
            d(fl,f) = cosine_similarity(a(:,fl),b(:,fl));

            % retrieve time
            idx = ismember(acquisitionTimeList(:,1),lower([siteList{idxSite(f,2)} '.' firstLevelList{fl}]));
            t(fl,f) = acquisitionTimeList{idx,2};

          end

        end

    end

    % set the time to the middle of the run
    t = t + 13;

    % initialise a figure
    hf = figure('Color','w','Position',[400 400 800 600]);

    % set correct printing properties
    hf.PaperType = '<custom>';
    %set(h,'PaperUnits','centimeters');
    if strcmpi(hf.PaperUnits,'centimeters')
      hf.PaperSize = [30 25];
      hf.PaperPosition = [0 0 30 25];
    elseif strcmpi(hf.PaperUnits,'inches')
      hf.PaperSize = [12 10];
      hf.PaperPosition = [0 0 12 10];
    end
    hf.PaperPositionMode = 'auto';

    % retrieve the standard colours
    ha = gca;
    col = cell(1,2);
    col{1} = ha.ColorOrder(2,:);
    col{2} = ha.ColorOrder(3,:);

    % plot the first dataset (SMA FUN on SMA connectivity)
    hp = cell(1,2);
    hdSMA = fit(t(:,1),d(:,1),'poly1','Robust','bisquare');
    %hdSMA = fit(t(:,1),d(:,1),'poly1');
    hp{1} = plot(hdSMA,t(:,1),d(:,1));

    % plot the second datasets (FPC seed/FUN)
    hold on;
    hdFPC = fit(t(:,2),d(:,2),'poly1','Robust','bisquare');
    %hdFPC = fit(t(:,2),d(:,2),'poly1');
    hp{2} = plot(hdFPC,t(:,2),d(:,2));

    % adjust the plot lines and markers
    for p = 1:2
      hp{p}(1).Color = col{p};
      hp{p}(1).Marker = 'o';
      hp{p}(1).MarkerSize = 8;
      hp{p}(1).MarkerFaceColor = col{p};
      hp{p}(2).Color = col{p};
      hp{p}(2).LineStyle = '--';
      hp{p}(2).LineWidth = 1;
    end

    % set the axes
    ha.XLim = [30 120];
    ha.XTick = 30:30:120;
    switch flgTimeContrast
      case 'site', ha.YLim = [0.5 1];
      case 'seed', ha.YLim = [0.7 1];
    end
    ha.YTick = ha.YLim(1):0.1:ha.YLim(2);
    ha.Position = [0.2 0.2 0.7 0.6];
    ha.Box = 'off';
    ha.Box = 'off';
    ha.Color = 'w';
    ha.XColor = 'k';
    ha.YColor = 'k';
    ha.LineWidth = 1.5;
    ha.FontSize = 24;

    % add title
    ht = title(ha,'fingerprint similarity over time');
    ht.Units = 'normalized';
    ht.Position = [0.5 1.15 0];
    ht.Color = 'k';
    ht.FontSize = 32;
    ht.FontWeight = 'normal';

    % add axis labels
    xlabel('time after FUN (minutes)','FontSize',28);
    ha.XLabel.Units = 'normalized';
    ha.XLabel.Position = [0.5 -0.12 0];
    ylabel('similarity (beta)','FontSize',28);
    ha.YLabel.Units = 'normalized';
    ha.YLabel.Position = [-0.12 0.5 0];

    % add legend
    switch flgTimeContrast
      case 'seedsite'
        hl = legend({'effective','linear fit','non-effective','linear fit'},'Location','southeast','Box','off');
      otherwise
        hl = legend({'SMA','SMA-fit','FPC','FPC-fit'},'Location','southeast','Box','off');
    end
    hl.Title.String = 'FUN';
    hl.TextColor = 'k';
    hl.Title.Color = 'k';
    hl.Title.FontSize = 28;
    hl.Title.FontWeight = 'normal';
    hlPos = hl.Position;
    hlPos(1) = 3/4;
    hlPos(2) = 1/4;
    hl.Position = hlPos;

    % save figures
    if flgSave
      % save as png
      figName = fullfile(figDir,'similarity_time');
      export_fig([figName '.png'], '-png','-r600','-nocrop', hf);

      % save the figure as pdf without the legend and title
      hl.Visible = 'off';
      ht.Visible = 'off';
      if flgSaveForRealsies
        export_fig([figName '.pdf'], '-pdf','-r600','-nocrop', hf);
        %print([figName '.pdf'], '-dpdf', '-r600', hf);
      end
      hl.Visible = 'on';
      ht.Visible = 'on';
    end

end



% -------
%% stats
% -------

% stats can only be performed on first level data, not on group data
if ~strcmpi(flgAnaLevel,'group') && flgStats

  % restore the flgPlot variable (remove ' doNotPlot' flags)
  flgPlot = regexp(flgPlot,'^\w*','match'); flgPlot = flgPlot{1};

  % switch depending on data type
  switch flgPlot
    case 'fingerprint'

      % loop over connectivity seeds
      for s = 1:nSeed

        % loop over FUN sites
        for f = 1:nSite

          % select a subset of the FUN sites to compare
          idxSite = setdiff(1:nSite,f);

          % specify data
          a = squeeze(fingerprintAll{s}(:,idxSite(1),:));
          b = squeeze(fingerprintAll{s}(:,idxSite(2),:));

          % remove columns with NaNs
          a = a(:,~any(isnan(a),1));
          b = b(:,~any(isnan(b),1));

          % permutation test
          fprintf('\n\n\npermutation test of %s fingerprint between %s FUN and %s FUN\n\n',seedList{s},siteList{idxSite});
          stats = sm_comparegroups(a,b,nPerm,'cosine_similarity','normalize','none'); % the cosine-similarity tests for the shape of the fingerprint, which is of interest here
          disp(stats);

        end

      end


    case 'self'

      % restructure data to nSeed x nSite x nMonkey/nRun
      dat = cat(1,fingerprintAll{:});

      % reshape with the observations along the first axis
      data = dat(:);
      X = nan(size(dat));

      % populate the model regressors
      for s = 1:nSeed
        X(s,:,:) = s;
      end
      seed = X(:);

      for f = 1:nSite
        X(:,f,:) = f;
      end
      fun = X(:);

      nSamp = size(dat,3);
      for d = 1:nSamp
        X(:,:,d) = d;
      end
      sample = X(:);

      % convert to table
      tbl = table(data,seed,fun,sample);

      % The hypothesis of interest is to test an interaction between
      %
      %     FUN (SMA, FPC) x connectivity_seed (SMA, FPC)
      %
      % This interaction is the first model tested at f=1. The simple models, and
      % the f=2 and f=3 tests are only performed to be exhaustive, but are not
      % intended to be reported in the manuscript.

      % loop over FUN sites to test interactions
      for f = 1:nSite

        % fit a generalized linear mixed-effects model with interactions
        formula = 'data ~ 1 + seed * fun + (1 + seed * fun | sample)';
        fprintf('\n\ninteraction between FUN (%s, %s) and connectivity seed (SMA, FPC)\nestimating model...',siteList{setdiff(1:nSite,f)});
        mdlInteract = fitglme(tbl,formula,'Exclude',tbl.fun==f);
        fprintf(' done\n\n');
        disp(anova(mdlInteract));


        % simple effects per seed
        formula = 'data ~ 1 + fun + (1 + fun | sample)';
        mdlSMA = fitglme(tbl,formula,'Exclude',tbl.fun==f | tbl.seed==2);
        fprintf('\n\nsimple effect of FUN on SMA connectivity\n\n');
        disp(anova(mdlSMA));

        formula = 'data ~ 1 + fun + (1 + fun | sample)';
        mdlFPC = fitglme(tbl,formula,'Exclude',tbl.fun==f | tbl.seed==1);
        fprintf('\n\nsimple effect of FUN on FPC connectivity\n\n');
        disp(anova(mdlFPC));

      end

  end

  % save the whole workspace in the figure directory
  if flgSave
    save(fullfile(figDir,['workspace_stats_' flgPlot '.mat']));
  end

end


% save the group workspace
if flgSave && strcmpi(flgAnaLevel,'group')

  % save the whole workspace in the figure directory
  save(fullfile(figDir,['workspace_group_' flgPlot '.mat']));

end
