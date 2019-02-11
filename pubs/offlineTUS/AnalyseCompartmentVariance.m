% This script creates the figures and stats to analyse the total variance
% and explained percentage of variance in the GM and CSF compartments. The
% explained variance is the one of most interest.

%set(0,'DefaultFigureWindowStyle','docked')
set(0,'DefaultFigureWindowStyle','normal')

% settings
flgFig = 'S2val'; % choose between '4', 'S2', and 'S2val'
flgSave = true;
flgSaveForRealsies = true; % fail-safe switch
flgPlotDataPoints = true;   % plot individual data points on top of the bar plots

% overhead
anaDir = '/Volumes/rsfMRI/anaesthesia/analysis';
procDir = '/Volumes/rsfMRI/anaesthesia/proc';
figDir = ['~/projects/lennart/fun/dmFC/figures/fig' flgFig];
if ~exist(figDir,'dir'), mkdir(figDir); end

% specify design
monkeyList = {'MK2','MK3','MK1'};
suffixValidation = '';
switch flgFig
  case '4'
    funList = {'control','sma'};
    colVal = [1 2];
  case 'S2'
    funList = {'control','fpc','fpc'};
    %funList = {'control','fpc'};
    colVal = [1 3 3];
  case '4new'
    funList = {'control','sma','fpc','fpc'};
    colVal = [1 2 3 5];
  case 'S2val'
    funList = {'fpc','fpc','fpc'};
    monkeyList = {'MK4','MK5','MK6'};
    colVal = [5 5 5];
    suffixValidation = '_validation';
  case 'S2valnew'
    funList = {'fpc','fpc','fpc','fpc'};
    monkeyList = {'MK4','MK5','MK6'};
    colVal = [5 5 5 5];
    suffixValidation = '_validation';
end
runList = {'run1','run2','run3'};
%compartmentList = {'GM','CSF','WM'};
compartmentList = {'GM','CSF'};
nCompartment = numel(compartmentList);
dataTypeList = {'val','expl'};
nDataType = numel(dataTypeList);
compTypeList = {'mean','comp'};
nCompType = numel(compTypeList);


% ----------
%% retrieve
% ----------

% initialise data structures
nFun = numel(funList);
nMonkey = numel(monkeyList);
nRun = numel(runList);
nComp = 6;
S = [];
data = nan(nCompartment,nFun,nMonkey,nRun,nComp);
dims = size(data);
nDim = numel(dims);
S.val.dataAll = data;
S.expl.dataAll = data;

% retrieve data, loop over fun conditions
for f = 1:nFun
  funName = funList{f};
  
  % read instruction file
  instructFile = fullfile(procDir,funName,'instruct',['instructMergeFunc',suffixValidation,'.txt']);
  T = readtable(instructFile,'Delimiter',' \t','ReadVariableNames',false);
  
  % loop over monkeys
  for m = 1:nMonkey
    monkeyName = monkeyList{m};
    
    % retrieve session from instruction file
    idx = ismember(T.Var3,funName) & ismember(T.Var2,monkeyName);
    sessName = T.Var1(idx); sessName = sessName{1};
    
    % loop over runs
    for r = 1:nRun
      runName = runList{r};

      % loop over compartments
      for c = 1:nCompartment
        cName = compartmentList{c};
        switch cName
          case 'GM', maskName = 'GM';
          case 'CSF', maskName = 'CSFcore';
        end

        % retrieve Eigen values and proportion of variance explained
        valFile = fullfile(procDir,funName,monkeyName,sessName,'functional',runName,['func_' runName '_hpbs_' maskName '_compVal.txt']);
        S.val.dataAll(c,f,m,r,:) = load(valFile);
        
        explFil = fullfile(procDir,funName,monkeyName,sessName,'functional',runName,['func_' runName '_hpbs_' maskName '_compExpl.txt']);
        S.expl.dataAll(c,f,m,r,:) = load(explFil);
        
      end % for c = 1:nCompartment

    end % for r = 1:nRun
    
  end % for m = 1:nMonkey
  
end % for f = 1:nFun


% ------
%% aggregate
% ------

% which components to use as representation
idxComp = 1:5; 

% calculate means and standard error of the mean
% loop over datatype
for d = 1:nDataType
  dName = dataTypeList{d};

  % average or sum across the 5 principal components
  dataMean = S.(dName).dataAll(:,:,:,:,1);
  switch dName
    case 'val', dataComp = mean(S.(dName).dataAll(:,:,:,:,1+idxComp),nDim);
    case 'expl', dataComp = sum(S.(dName).dataAll(:,:,:,:,1+idxComp),nDim) .* 100; % convert ratio to percentage
  end
  S.(dName).data = cat(nDim,dataMean,dataComp);

  % data structure at first level: nCompartment x nFun x nMonkey x nRun x nComp

  % reshape with runs as repeated measures, get mean and stderr over runs
  % data structure at second level: nCompartment x nFun x (nMonkey*nRun) x nComp
  S.(dName).run.data = reshape(S.(dName).data,[dims(1:2) prod(dims(3:4)) nCompType]);
  S.(dName).run.mean = squeeze(mean(S.(dName).run.data,3));
  S.(dName).run.err = squeeze(sem(S.(dName).run.data,0,3));

  % calculate mean and stderr over subjects
  % data structure at second level: nCompartment x nFun x nMonkey x nComp
  S.(dName).subj.data = squeeze(mean(S.(dName).data,4));
  S.(dName).subj.mean = squeeze(mean(S.(dName).subj.data,3));
  S.(dName).subj.err = squeeze(sem(S.(dName).subj.data,0,3));

end


% ------
%% plot
% ------
dName = 'expl'; % plot either the 'expl'ained variance or the Eigen 'val'ue
sampleType = 'subj'; % consider either 'subj'ects or 'run's as samples
switch sampleType
  case 'subj', nSamp = nMonkey;
  case 'run', nSamp = nMonkey*nRun;
end
flgContrastErr = false;
%col = [0.85 0.85 0.85];
col = [0 0 0];
  
% loop over variable types
for t = 1:nCompType
  tName = compTypeList{t};

  % get data and error measure
  % data structure at group level: nCompartment x nFun x nCompType;
  datAll = S.(dName).(sampleType).data(:,:,:,t);
  dat = S.(dName).(sampleType).mean(:,:,t);
  err = S.(dName).(sampleType).err(:,:,t);

  % calculate the contrast error (GM <> CSF)
  if flgContrastErr
    datCon = squeeze(diff(S.(dName).(sampleType).data(:,:,:,t),1,2));
    err = repmat(sem(datCon,0,2),1,nFun);
  end

  % initialise a figure
  hf = figure('Color','w','Position',[400 400 800 600]);

  % set correct printing properties
  hf.PaperType = '<custom>';
  %set(h,'PaperUnits','centimeters');
  if strcmpi(hf.PaperUnits,'centimeters')
    hf.PaperSize = [20 15];
    hf.PaperPosition = [0 0 20 15];
  elseif strcmpi(hf.PaperUnits,'inches')
    hf.PaperSize = [8 6];
    hf.PaperPosition = [0 0 8 6];
  end
  
  % bar plot
  %hb = barerrorbar(dat,err,'LineWidth',2,'EdgeColor',col);
  hb = bar(dat,'LineStyle','none');
  ha = gca;
  for f = 1:nFun
    hb(f).FaceColor = ha.ColorOrder(colVal(f),:); % sky blue, rust red, yellow-orange
  end

  % get x positions of bar graph
  x = getbarx(hb);

   % add data points of first level
  if flgPlotDataPoints
    hold on;
    % loop over compartments
    for c = 1:nCompartment
      % repeat the x-coordinates of this seed for each data point
      xCompartment = repmat(x(c,:)',1,size(datAll,3));
      % move the data points slightly to the right
      xCompartment = xCompartment + 0.03;
      % extract the data points of this seed
      datCompartment = squeeze(datAll(c,:,:));
      % loop over samples
      for s = 1:nSamp
        plot(xCompartment(:,s),datCompartment(:,s),'Color',[0.5 0.5 0.5],'LineStyle','-','LineWidth',1,'Marker','o','MarkerSize',6);
      end
    end
    hold off;
  end
    
  
  % add errorbars, loop over first data dimension
  hold on;
  for d = 1:size(dat,2)
    errorbar(x(:,d),dat(:,d),err(:,d),'LineStyle','none','Color',col,'LineWidth',2);
  end
  hold off;

  % adjust plot (axis)
  ha.Position = [0.2 0.2 0.7 0.6];
  ha.XLim = [0.4 2.6];
  ha.Box = 'off';
  ha.Color = 'w';
  ha.XColor = col;
  ha.YColor = col;
  ha.LineWidth = 1.5;
  ha.FontSize = 24;

  % add title
  switch tName
    case 'mean', ht = title(ha,'temporal variance of the mean signal');
    case 'comp', ht = title(ha,'variance explained by principal components');
  end
  ht.Units = 'normalized';
  ht.Position = [0.5 1.15 0];
  ht.Color = col;
  ht.FontSize = 32;
  ht.FontWeight = 'normal';
  
  % add legend
  %hl = legend(funList,'Location','north','Box','off');
  hl = legend(funList,'Position',[1/3 2/3 0.1375 0.1558],'Box','off');
  hl.Title.String = 'FUN';
  hl.TextColor = col;
  hl.Title.Color = col;
  hl.Title.FontSize = 28;
  hl.Title.FontWeight = 'normal';
  
  % add axis labels
  ha.XLim = [0.4 2.6];
  xlabel('compartment','FontSize',28);
  ha.XLabel.Units = 'normalized';
  ha.XLabel.Position = [0.5 -0.12 0];
  ha.XTickLabel = {'gray matter','CSF'};
  switch tName
    case 'mean'
      ylabel('variance (a.u.)','FontSize',28);
      ha.YLim = [0 0.3];
      ha.YTick = 0:0.1:0.3;
    case 'comp'
      ylabel('explained variance (%)','FontSize',28);
      ha.YLim = [0 20];
      ha.YTick = 0:5:20;
  end
  ha.YLabel.Units = 'normalized';
  ha.YLabel.Position = [-0.12 0.5 0];
  
  % save to disk as png and pdf
  if flgSave
    % set the figure name
    switch tName
      case 'mean'
        figName = fullfile(figDir,'var_total');
      case 'comp'
        figName = fullfile(figDir,'var_explained');
    end
    
    % save the figure
    export_fig([figName '.png'],'-png','-r600','-nocrop',hf);
    export_fig([figName '_flat.pdf'],'-pdf','-r600','-nocrop',hf);
    if flgSaveForRealsies
      print([figName '.pdf'], '-dpdf', '-r600', hf);
    end
    
  end
    
end

% return before doing the stats when plotting the validation data
if strcmpi(flgFig,'S1val') || strcmpi(flgFig,'S1valnew')
  return
end


% -------
%% stats
% -------
dName = 'expl'; % plot either the 'expl'ained variance or the Eigen 'val'ue
sampleType = 'subj'; % consider either 'subj'ects or 'run's as samples
switch sampleType
  case 'subj', nSamp = nMonkey;
  case 'run', nSamp = nMonkey*nRun;
end

% loop over variable types
for t = 1:nCompType
  tName = compTypeList{t};
  switch dName
    case 'val'
      switch tName
        case 'mean', str = 'standard deviation';
        case 'comp', str = 'Eigen value';
      end
    case 'expl'
      switch tName
        case 'mean', str = 'total variance';
        case 'comp', str = 'explained variance';
      end
  end

  % get data
  % data structure at second level: nCompartment x nFun x nMonkey/nRun x nCompType
  dat = S.(dName).(sampleType).data(:,:,:,t);
  
  % reshape with the observations along the first axis
  data = dat(:);
  X = nan(size(dat));
  
  % populate the model regressors
  for c = 1:nCompartment
    X(c,:,:) = c;
  end
  compartment = X(:);
  
  for f = 1:nFun
    X(:,f,:) = f;
  end
  fun = X(:);
  
  for s = 1:nSamp
    X(:,:,s) = s;
  end
  sample = X(:);
  
  % convert to table
  tbl = table(data,compartment,fun,sample);
  
  % fit a generalized linear mixed-effects model without interactions
  formula = 'data ~ 1 + compartment + fun + (1 + compartment + fun | sample)';
  mdlSimple = fitglme(tbl,formula);
  fprintf('\n\nGeneralized Linear Mixed-Effects of FUN x GM/CSF on %s\n\n',str);
  disp(anova(mdlSimple));
  
  % fit a GLME model with interactions
  % WARNING: not enough observations to converge
  % Forget about it, I didn't have any hypotheses about the interactions
  % anyway. I'm happy with my simple model.
  %formula = 'data ~ 1 + compartment * fun + (1 + compartment * fun | sample)';
  %mdlInteract = fitglme(tbl,formula);
  %disp(anova(mdlInteract));
  
  %compare(mdlSimple,mdlInteract)
  
  % simple effects
  tblGM = tbl(tbl.compartment==1,:);
  tblCSF = tbl(tbl.compartment==2,:);
  formula = 'data ~ 1 + fun + (1 + fun | sample)';
  mdlGM = fitglme(tblGM,formula);
  fprintf('\n\nsimple effect of FUN on %s in GM\n\n',str);
  disp(anova(mdlGM));
  formula = 'data ~ 1 + fun + (1 + fun | sample)';
  mdlCSF = fitglme(tblCSF,formula);
  fprintf('\n\nsimple effect of FUN on %s in CSF\n\n',str);
  disp(anova(mdlCSF));

  % interaction simple effects
  tblControl = tbl(tbl.fun==1,:);
  tblSMA = tbl(tbl.fun==2,:);
  tblDiff = tblControl;
  tblDiff.data = tblSMA.data - tblControl.data;
  formula = 'data ~ 1 + compartment + (1 + compartment | sample)';
  mdlInteractFake = fitglme(tblDiff,formula);
  fprintf('\n\nfake interaction effect of FUN by GM/CSF on %s\n\n',str);
  disp(anova(mdlInteractFake));
  
end

% save the whole workspace in the figure directory
if flgSave
  save(fullfile(figDir,'workspace.mat'));
end
