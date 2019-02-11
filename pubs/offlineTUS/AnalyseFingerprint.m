%------------------------------------------------------------------
% This script plots and runs statistics for connectional fingerprints and
% self-connections.
%
% To analyse the fingerprints, run this script with:
%   flgPlot = 'fingerprint';
%
% To analyse the self-connections, run this script with:
%   flgPlot = 'self';
%   flgAnaLevel = 'subj';
% and then again with:
%   flgAnaLevel = 'group';
%
%
% To analyse the SMA/FPC coupling with A1, run this script with:
%   flgPlot = 'auditory';
%
% To analyse the correlation between TUS effects on SMA/FPC and on A1:
%   flgPlot = 'auditorycorr';
%
% To analyse the group results, run this script once with:
%   flgAnaLevel = 'group';
%
% To get errorbars in the plot, run it twice in succession:
%   1. flgAnaLevel = 'subjrun';
%   2. flgAnaLevel = 'group';
%
% To get fingerprint statistics over the runs, run it once with:
%   flgPlot = 'fingerprint';
%   flgAnaLevel = 'subjrun';
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
flgPlot = 'auditory';        % 'fingerprint', 'self', 'time', 'auditory', 'auditorycorr': plot either the fingerprints, the self-connections, the time-analysis, or the auditory analysis
flgAnaLevel = 'group';       % group, subj, subjrun, sess, run, sessrun
flgStats = false;           % do or do not perform stats
flgPlotFirstLevel = 'mean';  % 'all','mean','none', plot all datasets of the first-level, plot the mean, or do not plot and just keep the error description to plot onto the group average
flgPlotDataPoints = true;   % plot individual data points on top of the bar plots
flgSave = false;            % do or do not save figures and workspace
flgSaveForRealsies = false; % yeah, do this only once, for real. This is an extra hurdle to prevent you from overwriting the most valuable figures without thinking
flgValidate = false;       % run the original dataset or a validation analysis
flgTargetListAuditory = 'fpc';  % copy the targetList for the auditory control from either 'sma' or 'fpc'
if strcmpi(flgPlot,'auditory'), flgTargetListAuditory = 'auditory'; end

% pick data file names and directories
anaDir = '/Volumes/rsfMRI/anaesthesia/analysis';
if ~exist(anaDir,'dir')
  anaDir = '~/projects/lennart/fun/dmFC/figures';
end
workDir = fullfile(anaDir,'fingerprint');
if ~strcmpi(flgTargetListAuditory,'none')
  % hack
  %workDir = fullfile(workDir,'auditory');
end
if flgValidate
  workDir = fullfile(workDir,'validation');
end
workDir = fullfile(workDir,flgAnaLevel);

switch flgAnaLevel
  case 'group'
    firstLevelList = {''};
  case 'subj'
    if ~flgValidate
      firstLevelList = {'MK2','MK1','MK3'};
    else
      firstLevelList = {'MK4','MK5','MK6'};
    end
  case 'sess'
    % not yet supported
  case 'run'
    firstLevelList = {'run1','run2','run3'};
    %firstLevelList = {'run1'}; % HACK to plot each run individually
  case 'subjrun'
    if ~flgValidate
      firstLevelList = {'MK2.run1','MK2.run2','MK2.run3', ...
                        'MK1.run1','MK1.run2','MK1.run3', ...
                        'MK3.run1','MK3.run2','MK3.run3'};
      %firstLevelList = {'MK2.run1', ...
      %                  'MK1.run1', ...
      %                  'MK3.run1'}; % HACK to plot each run individually
    else
      firstLevelList = {'MK4.run1','MK4.run2','MK4.run3', ...
                        'MK5.run1','MK5.run2','MK5.run3', ...
                        'MK6.run1','MK6.run2','MK6.run3'};
    end
end

% specify the acquisition time
flgTimeContrast = 'seedsite'; % constrast either 'seed', 'site', or 'seedsite'
acquisitionTimeList = {'sma.MK2.run1',55
                       'sma.MK2.run2',81
                       'sma.MK2.run3',107
                       'sma.MK1.run1',50
                       'sma.MK1.run2',76
                       'sma.MK1.run3',102
                       'sma.MK3.run1',35
                       'sma.MK3.run2',61
                       'sma.MK3.run3',87
                       'fpc.MK2.run1',30
                       'fpc.MK2.run2',56
                       'fpc.MK2.run3',82
                       'fpc.MK1.run1',30
                       'fpc.MK1.run2',56
                       'fpc.MK1.run3',82
                       'fpc.MK3.run1',25
                       'fpc.MK3.run2',51
                       'fpc.MK3.run3',77
                       'fpc.MK4.run1',60
                       'fpc.MK4.run2',82
                       'fpc.MK4.run3',112
                       'fpc.MK5.run1',20
                       'fpc.MK5.run2',46
                       'fpc.MK5.run3',72
                       'fpc.MK6.run1',45
                       'fpc.MK6.run2',71
                       'fpc.MK6.run3',97};

% set from which hemisphere to draw or combine the connectivity
% flgCombineHemi          % 'left', 'right': left or right inter-hemispheric connectivity
                          % 'inter': average of inter-hemispheric connectivity
                          % 'bilat': the average of the bilateral connectivity
% set the hemisphere combination flag based on the type of plot
switch flgPlot
  case 'self'
    flgCombineHemi = 'inter';
  otherwise
    flgCombineHemi = 'bilat';
end
flgScaleErr = false;      % scale the error term with respect to the effect size, this only makes sense to represent error terms from one dataset onto another
flgErrDescrip = 'sem';    % how to describe the error, as 'sem' or 'range'
flgCapZstat = true;       % cap z-stats between [-2 2] (a sensible idea) or do not limit the stat

% adjust the workDir
if ~flgCapZstat
  workDir = fullfile(fileparts(workDir),'noCap','median');
end

% set figure directory
if flgValidate
  figDir = '~/projects/lennart/fun/dmFC/figures/figS2';
elseif (strcmpi(flgAnaLevel,'run') && numel(firstLevelList)==1) || strcmpi(flgPlot,'time')
  figDir = '~/projects/lennart/fun/dmFC/figures/figS3';
else
  figDir = '~/projects/lennart/fun/dmFC/figures/fig3';
end
if strcmpi(flgPlot,'fingerprint') && ~strcmpi(flgTargetListAuditory,'none')
  figDir = ['~/projects/lennart/fun/dmFC/figures/fig3/auditory/',flgTargetListAuditory];
end
if ~exist(figDir,'dir'), mkdir(figDir); end

%set(0,'DefaultFigureWindowStyle','docked')
set(0,'DefaultFigureWindowStyle','normal')

% set colour and suffic for the validation plot
if flgValidate
  colVal = 5;
  strValidate = '_validate';
else
  colVal = [];
  strValidate = '';
end


%---------------
%% load targets
%---------------

% load the instruction file containing the fingerprint site, seed, and targets
instructFile = fullfile(anaDir,'instruct',['instructExtractFingerprint' strValidate '.txt']);
if exist(instructFile,'file')
  fingerprintList = regexp(importdata(instructFile),' ','split');
else
  load('~/projects/lennart/fun/dmFC/figures/fig3/workspace_fingerprint.mat','fingerprintList');
  if ~strcmpi(flgTargetListAuditory,'none') && ~any(cellfun(@(x) strcmpi(x{2},'A1'),fingerprintList))
    load('~/projects/lennart/fun/dmFC/figures/fig3/auditory/sma/workspace_stats_fingerprint.mat','fingerprintList');
  end
end

% extract fingerprint site, seed, targets, and first-level conditions
nFingerprint = numel(fingerprintList);
siteList = unique(cellfun(@(x) x{1},fingerprintList,'UniformOutput',false));
nSite = numel(siteList);
seedList = unique(cellfun(@(x) x{2},fingerprintList,'UniformOutput',false));
nSeed = numel(seedList);
nFirstLevel = numel(firstLevelList);

% re-order the seeds and sites
prefOrder = {'control','sma','psma','fpc','pgacc','amyg','lofc','midsts','pcontrol','ppsma','pv1','A1'};
[~,idxPrefOrder] = ismember(prefOrder,siteList);
idxPrefOrder = idxPrefOrder(idxPrefOrder>0);
siteList = siteList(idxPrefOrder);
[~,idxPrefOrder] = ismember(prefOrder,seedList);
idxPrefOrder = idxPrefOrder(idxPrefOrder>0);
seedList = seedList(idxPrefOrder);

% switch between plotting the fingerprint and self-connection
switch flgPlot
  case {'fingerprint','time','auditorycorr'}
    % ignore self projections
    for f = 1:nFingerprint
      %fingerprintList{f} = [fingerprintList{f}(1:2) setdiff(fingerprintList{f}(3:end),fingerprintList{f}(2),'stable')];
      % ignore self AND auditory targets
      fingerprintList{f} = [fingerprintList{f}(1:2) setdiff(fingerprintList{f}(3:end),[fingerprintList{f}(2) 'A1'],'stable')];
    end
  case 'self'
    % keep only the self projections
    for f = 1:nFingerprint
      fingerprintList{f} = fingerprintList{f}([1 2 2]);
    end
  case 'auditory'
%     idx = find(cellfun(@(x) strcmpi(x{2},'A1'),fingerprintList));
%     seedList = {'A1'};
%     nSeed = numel(seedList);
%     fingerprintList = cell(numel(idx),1);
%     for f = 1:numel(idx)
%       fingerprintList{f} = [tmp{idx(f)}(1) 'A1' 'sma' 'fpc'];
%     end
    seedList = {'sma','fpc'};
    nSeed = numel(seedList);
    fingerprintList = cell(6,1);
    f = 0;
    for s = 1:nSite
      for ss = 1:nSeed
        f = f+1;
        fingerprintList{f} = {siteList{s} seedList{ss} 'A1'};
      end
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
  if ~strcmpi(seedList{s},'A1') || strcmpi(flgPlot,'auditory')
    idx = find(cellfun(@(x) strcmpi(x{2},seedList{s}),fingerprintList),1,'first');
  else
    % copy the A1 targets from a prefered alternative
    idx = find(cellfun(@(x) strcmpi(x{2},flgTargetListAuditory),fingerprintList),1,'first');
  end
  targetList{s} = fingerprintList{idx}(3:end);
  % initialise the data structure
  nTarget = numel(targetList{s});
  fingerprint{s} = nan(nTarget,nSite,nFirstLevel);
end


%----------------
%% retrieve data
%----------------

% loop over FUN sites
for ss = 1:nSite
  siteName = siteList{ss};

  % loop over first-level conditions (empty when group-level analysis)
  for fl = 1:nFirstLevel

    % set the name of the first level conditions
    firstLevelName = firstLevelList{fl};
    % prepad with a period, if not already done so
    if ~isempty(firstLevelName) && isempty(regexp(firstLevelName,'^\..*','once'))
      firstLevelName = ['.' firstLevelName];
    end

    % define fingerprint data file
    fingerprintFile = fullfile(workDir,[siteName firstLevelName '.txt']);

    % read in the fingerprint text file
    T = readtable(fingerprintFile,'ReadVariableNames',false,'ReadRowNames',true);

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
renameList = {'pgacc','ACC'; 'amyg','amygdala'; 'sma','SMA'; 'fpc','FPC'; 'midsts','midSTS'; 'M1lat','M1'; 'lofcChau','47-12o'; '9mc','9m'};
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
if nFirstLevel > 1 && ~strcmpi(flgPlotFirstLevel,'all')
  fingerprintAll = fingerprint;
  fingerprintAllDeMean = fingerprint;
  fingerprintErr = cell(1,2);
  for s = 1:nSeed
    fingerprint{s} = mean(fingerprintAll{s},3);
    fingerprintAllDeMean{s} = bsxfun(@minus,fingerprintAll{s},fingerprint{s});
    switch flgErrDescrip
      case 'range', fingerprintErr{s} = bsxfun(@minus,cat(4,min(fingerprintAll{s},[],3),max(fingerprintAll{s},[],3)),fingerprint{s});
      otherwise, fingerprintErr{s} = sem(fingerprintAll{s},0,3);
    end
    % rescale with respect to a robust maximum of the mean fingerprint
    if flgScaleErr
      maxMagn = sort(abs(fingerprint{s}),1,'descend');
      if nTarget > 3
        maxMagn = mean(maxMagn(1:3,:),1);
      else
        maxMagn = mean(maxMagn,1);
      end
      fingerprintErr{s} = bsxfun(@rdivide,fingerprintErr{s},maxMagn);
      fingerprintAllDeMean{s} = bsxfun(@rdivide,fingerprintAllDeMean{s},maxMagn);
      % mark that scaling has yet to be performed
      flgScaleErrDone = false;
    end
  end
  % continue to plot the mean over the first-level, or stop here
  if strcmpi(flgPlotFirstLevel,'mean')
    nFirstLevel = 1;
  else
    % do not plot the mean but jump straight to the stats
    flgPlot = [flgPlot ' doNotPlot'];
  end
elseif exist('fingerprintErr','var') && flgScaleErr && ~(exist('flgScaleErrDone','var') && flgScaleErrDone)
  % loop over seeds
  for s = 1:nSeed
    % rescale with respect to a robust maximum of the mean fingerprint
    maxMagn = sort(abs(fingerprint{s}),1,'descend');
    if nTarget > 3
      maxMagn = mean(maxMagn(1:3,:),1);
    else
      maxMagn = mean(maxMagn,1);
    end
    fingerprintErr{s} = bsxfun(@times,fingerprintErr{s},maxMagn);
    fingerprintAllDeMean{s} = bsxfun(@times,fingerprintAllDeMean{s},maxMagn);
  end
  % mark that scaling has been performed
  flgScaleErrDone = true;
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
    figHandle = cell(nSeed,nFirstLevel);
    for s = 1:nSeed
      range = [];
      switch seedList{s}
        case 'amygdala', range = [-0.04 0.12]; NrTickMarks = 4;
        case 'ACC', range = [0 0.16]; NrTickMarks = 4;
        case 'SMA', range = [-0.4 0.6]; NrTickMarks = 5;
        case 'FPC', range = [-0.4 0.6]; NrTickMarks = 5;
        case 'A1'
          if strcmpi(flgTargetListAuditory,'SMA')
            range = [-0.4 0.6]; NrTickMarks = 5;
          elseif strcmpi(flgTargetListAuditory,'FPC')
            range = [-0.4 0.6]; NrTickMarks = 5;
          end
      end

      % HACK: overwrite range
      if nFirstLevel > 1, range = [-0.5 0.75]; NrTickMarks = 5; end
      if nFirstLevel > 3, range = [-0.6 1.2]; NrTickMarks = 4; end

      % loop over conditions within the analysis level
      for fl = 1:nFirstLevel

        % set the name of the first level conditions
        firstLevelName = firstLevelList{fl};

        % define the title
        titleStr = [seedList{s} ' fingerprint'];
        if nFirstLevel > 1, titleStr = sprintf('%s\n%s: %s',titleStr,flgAnaLevel,firstLevelName); end

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
          hf = subplot(nSeed,nFirstLevel,p);

        end

        % draw the spider plot
        if exist('fingerprintErr','var')
          err = squeeze(fingerprintErr{s}(:,:,fl,:));
          hS = spider_wedge(fingerprint{s}(:,:,fl),err,'Handle',hf,'PlotType','line','PlotTypeErr','cloud','AlphaErr',0.2,'LineWidth',4,'Color',colVal,'Scale','none','Title','','Label',targetList{s},'Legend',siteList,'Range',range,'NrTickMarks',NrTickMarks,'Web',true,'RefLine',0,'ReturnAllHandles',true);
        else
          hS = spider_wedge(fingerprint{s}(:,:,fl),'Handle',hf,'PlotType','line','PlotTypeErr','cloud','LineWidth',4,'Color',colVal,'Scale','none','Title','','Label',targetList{s},'Legend',siteList,'Range',range,'NrTickMarks',NrTickMarks,'Web',true,'RefLine',0,'ReturnAllHandles',true);
        end

        % do not polish subplots
        if ~flgFigure
          hS.title = title(titleStr);
          hS.title.Visible = 'on';
          if p < nSeed * nFirstLevel
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
          figName = fullfile(figDir,['fingerprint_' seedList{s} firstLevelName strValidate]);
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


  case {'self','auditory'}

    % restructure the fingerprint into a matrix
    dat = vertcat(fingerprint{:});
    err = vertcat(fingerprintErr{:});
    datAll = vertcat(fingerprintAllDeMean{:});

    % concatenate horizontally, when only one site is available
    %if nSite==1 && nFirstLevel==1
    %  dat = dat';
    %  err = err';
    %end

    % ignore the control condition
    %idxIncl = ~ismember(siteList,'control');
    %siteList = siteList(idxIncl);
    %dat = dat(idxIncl,:);
    %err = err(idxIncl,:);

    % specify y-range
    switch flgPlot
      case 'self'
        strTitle = 'strength of self-connections';
        strYLabel = 'self connection (Fisher''s z)';
        strFigName = 'selfConn';
        switch flgAnaLevel
          case 'group'
            if flgCapZstat, yLimits = [1.3 1.7]; else, yLimits = [1.5 2]; end
          otherwise
            if flgCapZstat, yLimits = [1.1 1.4]; else, yLimits = [0 5]; end
        end
      otherwise
        strTitle = 'coupling with auditory cortex';
        strYLabel = 'coupling strength (Fisher''s z)';
        strFigName = 'auditoryConn';
        yLimits = [-0.4 0.4];
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

    % add data points of first level
    if flgPlotDataPoints
      hold on;
      % centre the data points around the group coordinates
      datAllReCentre = bsxfun(@plus,datAll,dat);
      % loop over seeds
      for s = 1:nSeed
        % repeat the x-coordinates of this seed for each data point
        xSeed = repmat(x(s,:)',1,size(datAll,3));
        % move the data points slightly to the right
        xSeed = xSeed + 0.03;
        % extract the data points of this seed
        datSeed = squeeze(datAllReCentre(s,:,:));
        % loop over samples
        for d = 1:nSamp
          plot(xSeed(:,d),datSeed(:,d),'Color',[0.5 0.5 0.5],'LineStyle','-','LineWidth',1,'Marker','o','MarkerSize',6);
        end
      end
      hold off;
    end

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
    ht = title(ha,strTitle);
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
    ylabel(strYLabel,'FontSize',28);
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
      figName = fullfile(figDir,[strFigName strValidate]);
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

    A = 1;

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
      figName = fullfile(figDir,['similarity_time' strValidate]);
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

          % permutation test
          fprintf('\n\n\npermutation test of %s fingerprint between %s FUN and %s FUN\n\n',seedList{s},siteList{idxSite});
          stats = sm_comparegroups(a,b,inf,'cosine_similarity','normalize','none');
          disp(stats);

        end

      end


    case {'self','auditory'}

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
      %fun = categorical(X(:));
      fun = X(:);

      nSamp = size(dat,3);
      for d = 1:nSamp
        X(:,:,d) = d;
      end
      sample = X(:);

      % convert to table
      tbl = table(data,seed,fun,sample);

      switch flgPlot
        case 'auditory'

          % fit a generalized linear mixed-effects model with interactions
          formula = 'data ~ 1 + seed * fun + (1 + seed * fun | sample)';
          fprintf('\n\ninteraction between FUN and connectivity seed (SMA, FPC)\nestimating model...');
          %mdlInteract = fitglme(tbl,formula);
          mdlInteract = fitglme(tbl,formula,'Exclude',double(tbl.fun)==1); % to mimic the self-connection analyses
          fprintf(' done\n\n');
          disp(anova(mdlInteract));

          % simple effects per seed
          formula = 'data ~ 1 + fun + (1 + fun | sample)';
          mdlSMA = fitglme(tbl,formula,'Exclude',tbl.seed==2);
          fprintf('\n\nsimple effect of FUN on SMA connectivity\n\n');
          disp(anova(mdlSMA));

          formula = 'data ~ 1 + fun + (1 + fun | sample)';
          mdlFPC = fitglme(tbl,formula,'Exclude',tbl.seed==1);
          fprintf('\n\nsimple effect of FUN on FPC connectivity\n\n');
          disp(anova(mdlFPC));


        otherwise

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
          mdlInteract = fitglme(tbl,formula,'Exclude',double(tbl.fun)==f | tbl.seed==3);
          fprintf(' done\n\n');
          disp(anova(mdlInteract));


          % simple effects per seed
          formula = 'data ~ 1 + fun + (1 + fun | sample)';
          mdlSMA = fitglme(tbl,formula,'Exclude',double(tbl.fun)==f | tbl.seed==2 | tbl.seed==3);
          fprintf('\n\nsimple effect of FUN on SMA connectivity\n\n');
          disp(anova(mdlSMA));

          formula = 'data ~ 1 + fun + (1 + fun | sample)';
          mdlFPC = fitglme(tbl,formula,'Exclude',double(tbl.fun)==f | tbl.seed==1 | tbl.seed==3);
          fprintf('\n\nsimple effect of FUN on FPC connectivity\n\n');
          disp(anova(mdlFPC));

        end

      end

  end

  % save the whole workspace in the figure directory
  if flgSave
    save(fullfile(figDir,['workspace_stats' strValidate '_' flgPlot '.mat']));
  end

end


% save the group workspace
if flgSave && strcmpi(flgAnaLevel,'group')

  % save the whole workspace in the figure directory
  save(fullfile(figDir,['workspace_group' strValidate '_' flgPlot '.mat']));

end
