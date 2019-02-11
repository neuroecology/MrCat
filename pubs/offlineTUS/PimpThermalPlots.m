% pimp the thermal plots
workDir = '~/projects/lennart/fun/dmFC/figures/fig1/simulation/thermal';

% save or not to save
flgSave = false;

% specify number of steps in colormap
stps = 2^9;

siteList = {'SMA'}; % {'SMA','FPC'};
for s = 1:numel(siteList)
  site = siteList{s};
  
  % load the pressure/temperature map;
  importdata(fullfile(workDir,['P et Tmax ' site '.fig']));
  hf = gcf;
  
  % get positions of three horizontal sub-plots
  pos = cell(1,6);
  hfTmp = figure;
  hLeft = subplot(1,3,1); pos{6} = hLeft.Position;
  hMiddle = subplot(1,3,2); pos{4} = hMiddle.Position;
  hRight = subplot(1,3,3); pos{2} = hRight.Position;
  close(hfTmp);
  
  % reposition the subplots
  for c = 2:2:6
    ha = hf.Children(c);
    ha.Position = pos{c};
    xData = ha.Children.XData;
    yData = ha.Children.YData;
    ha.Children.XData = yData;
    ha.Children.YData = xData;
    ha.Children.CData = ha.Children.CData';
    axis(ha,'tight');
    axis(ha,'equal');
  end
  
  % bring the color bar to the bottom
  for c = 1:2:6
    hf.Children(c).Location = 'southoutside';
  end
  
  
  % set the scaling type
  flgScale = 'not';
  %flgScale = 'log';
  %flgScale = 'sqrt';
  CLimRef = [36.5 37.5];
  %CLimRef = [36 38];
  
  % rescale the temperature plots
  for c = 2:2:6
    ha = hf.Children(c);
    hs = ha.Children;
    
    % rescale the pressure and temperature plots
    if c == 6
      
      ha.CLim = [0 1.5];
      
    else
      
      % set some reasonable temperature limits
      if strcmpi(flgScale,'not')
        
        ha.CLim = CLimRef;
      
      else
      
        % retrieve the data
        datOrig = hs.CData;
        dat = datOrig;

        % process positive and negative data separately
        idxPos = dat>=37;
        idxNeg = dat<37;
        datPos = dat;
        datPos(idxNeg) = 37;
        datNeg = dat;
        datNeg(idxPos) = 37;

        % scale symmetrical around 37C
        if strcmpi(flgScale,'log')
          datPos = 37 + log(datPos - min(CLimRef));
          datNeg = 37 - log(-(datNeg - max(CLimRef)));
        else
          datPos = 37 + sqrt(datPos - 37);
          datNeg = 37 - sqrt(-(datNeg - 37));
        end

        % put the data back together
        datLog = dat;
        datLog(idxPos) = datPos(idxPos);
        datLog(idxNeg) = datNeg(idxNeg);

        % and back in the figure
        ha.Children.CData = datLog;

        % rescale colours to the log10 equivalent of [36 38]
        if strcmpi(flgScale,'log')
          ha.CLim = 37 + [-log(2) log(2)];
          ha.CLim = 37 + [-log(1.5) log(1.5)];
        else
          ha.CLim = 37 + [-sqrt(1.5) sqrt(1.5)];
          ha.CLim = 37 + [-sqrt(0.5) sqrt(0.5)];
        end
        
      end

    end
    
    % store the color scale
    CLim = ha.CLim;
    
    % extract data
    X = get(hs,'XData');
    Y = get(hs,'YData');
    Z = get(hs,'CData');
    
    % ensure proper boundaries
    X = X(1:size(Z,2));
    Y = Y(1:size(Z,1));
    
    % expand matrix. This is necessary because the original plot was made
    % using image
    x_step = mode(abs(diff(X)));
    y_step = mode(abs(diff(Y)));
    X = [X(1)-x_step X X(end)+x_step];
    Y = [Y(1)-y_step Y Y(end)+y_step];
    Z = [Z(:,1) Z Z(:,end)];
    Z = [Z(1,:); Z; Z(end,:)];
    
    % initialise a new figure
    hfn = figure('Color','w','Position',[400 400 400 800]);
    
    % set correct printing properties
    hfn.PaperType = '<custom>';
    %set(h,'PaperUnits','centimeters');
    if strcmpi(hfn.PaperUnits,'centimeters')
      hfn.PaperSize = [30 30];
      hfn.PaperPosition = [0 0 30 30];
    elseif strcmpi(hfn.PaperUnits,'inches')
      hfn.PaperSize = [12 12];
      hfn.PaperPosition = [0 0 12 12];
    end
    hfn.PaperPositionMode = 'auto';
    
    % draw the contour map
    [~,hn] = contourf(X,Y,Z,stps,'LineStyle','none');
    
    % set the colormap to the same color resolution
    %colormap(jet(stps));
    colormap(parula(stps));
    
    % set the axis
    axis equal;
    %axis([min(X)+x_step/2 max(X)-x_step/2 min(Y)+y_step/2 max(Y)-y_step/2]);
    axis([min(X)+x_step max(X)-x_step min(Y)+y_step max(Y)-y_step]);
    han = gca;
    
    % set the color bar
    han.CLim = CLim;
    hc = colorbar('southoutside');
    hc.FontSize = 18;
    hc.Box = 'off';
    hc.LineWidth = 0.5;
    hc.TickDirection = 'out';
    
    % adjust the axis
    han.Color = 'w';
    han.XColor = 'k';
    han.YColor = 'k';
    han.LineWidth = 1.5;
    han.FontSize = 18;
    
    % add title
    if c == 2
      strTitle = 'temperature_skull';
    elseif c == 4
      strTitle = 'temperature';
    elseif c == 6
      strTitle = 'pressure';
    else
      strTitle = 'oops';
    end
    ht = title(han,strTitle,'interpreter','none');
    ht.Units = 'normalized';
    ht.Position = [0.5 1.02 0];
    ht.Color = 'k';
    ht.FontSize = 24;
    ht.FontWeight = 'normal';
    
    % save the figure
    if flgSave
      
      % save as png
      figName = fullfile(workDir,strTitle);
      %export_fig([figName '.png'], '-png','-r600','-nocrop', hfn);
      
      % save a naked png
      ht.Visible = 'off';
      han.Visible = 'off';
      hc.Visible = 'off';
      export_fig([figName '_naked.png'], '-png','-r600', hfn);
      han.Visible = 'on';
      hc.Visible = 'on';
      
      % save the figure as pdf without the title
      export_fig([figName '_flat.pdf'], '-pdf','-r600','-nocrop', hfn);
      print([figName '.pdf'], '-dpdf', '-r600', hfn);
      
      % make everything visible again
      hl.Visible = 'on';
      
    end
    
  end
  
  
  % load the temporal evolution
  importdata(fullfile(workDir,'T 3 curves SMA.fig'));
  hf = gcf;
  
  % reset the figure color and position
  hf.Color = 'w';
  hf.Position = [400 400 800 800];
  
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
  
  % adjust the axis
  ha = gca;
  ha.Position = [0.2 0.15 0.7 0.7];
  ha.Color = 'w';
  ha.XColor = 'k';
  ha.YColor = 'k';
  ha.LineWidth = 1.5;
  ha.FontSize = 24;
  ha.GridLineStyle = 'none';
  ha.Box = 'off';
  ha.Children(1).LineWidth = 3;
  ha.Children(2).LineWidth = 3;
  ha.Children(3).LineWidth = 3;
  
  % adjust the axis labels
  ha.XLabel.String = 'time (s)';
  ha.XLabel.FontSize = 28;
  ha.XLabel.Units = 'normalized';
  ha.XLabel.Position = [0.5 -0.1 0];
  ha.YLim = [35 40];
  ha.YTick = [35 36 37 38 39 40];
  ha.YLabel.String = 'temperature (C)';
  ha.YLabel.FontSize = 28;
  ha.YLabel.Units = 'normalized';
  ha.YLabel.Position = [-0.16 0.5 0];
  
  % adjust the legend
  hf.Children(1).String = {'max skull','max brain','focal point'};
  hf.Children(1).Location = 'northeast';
  hf.Children(1).Box = 'off';
  hf.Children(1).FontSize = 24;
  
  % adjust the title
  ht = ha.Title;
  ht.Units = 'normalized';
  ht.Position = [0.5 1.1 0];
  ht.Color = 'k';
  ht.FontSize = 32;
  ht.FontWeight = 'normal';
  ht.String = 'temperature evolution';
  
  % save the figure
  if flgSave
    
    % save as png
    figName = fullfile(workDir,'temperature_dynamics');
    export_fig([figName '.png'], '-png','-r600','-nocrop', hf);
    
    % save the figure as pdf without the title
    ht.Visible = 'off';
    export_fig([figName '_flat.pdf'], '-pdf','-r600','-nocrop', hf);
    print([figName '.pdf'], '-dpdf', '-r600', hf);
    ht.Visible = 'on';
    
  end
  
end


% T = 37 + [-(1^2) -(0.5^2) 0.5^2 1^2]
% hf.Children(1).Ticks
% 
% hf.Children(1).Ticks = 37 + [-sqrt([1.5 1 0.2]) 0 sqrt([0.2 1 1.5])]
% figName = fullfile(workDir,'bar');
