% pimp the intensity plots

siteList = {'SMA','FPC'};
workDir = '~/projects/lennart/fun/dmFC/figures/fig1/simulation/intensity_oct2018';
%siteList = {'ACC','amygdala'};
%workDir = '~/projects/lennart/fun/deepFUN/figures2/fig1/simulations';
nSite = numel(siteList);

% save or not to save
flgSave = true;

% draw everything, or only the skull, or beam
flgDraw = 'everything';

% make vector based or not
switch flgDraw
  case 'beam'
    flgVector = true;
  otherwise
    flgVector = false;
end

% the colour scaling of the intensity maps
CLim = [10 25];

% loop over figures
for s = 1:nSite
  site = siteList{s};
  switch site
    case 'FPC', ver = ''; % ver = '_v1';
    otherwise, ver = '';
  end
  
  % load the pressure/temperature map;
  importdata(fullfile([workDir ver],['Isppa ' siteList{s} ' dry skull.fig']));
  hf = gcf;

  % bring the color bar to the right
  for c = 1:2:6
    % right
    hf.Children(c).Location = 'eastoutside';
    % bottom
    %hf.Children(c).Location = 'southoutside';
  end

  % transpose the sagittal and coronal slices
  for c = [4 6]
    ha = hf.Children(c);
    X = ha.Children(1).XData;
    Y = ha.Children(1).YData;
    Z = ha.Children(1).CData;
    % swap the X and Y
    ha.Children(1).XData = Y;
    ha.Children(1).YData = X;
    if flgVector
      ha.Children(1).CData = ha.Children(1).CData';
    else
      ha.Children(1).CData = fliplr(rot90(ha.Children(1).CData));
    end
    axis(ha,'equal');
    %axis(ha,'tight');
  end

  % rescale the intensity plots
  for c = 6
    ha = hf.Children(c);
    hs = ha.Children(1);

    % store the color scale
    %CLim = ha.CLim;
    ha.CLim = CLim;
      
    % extract data
    X = get(hs,'XData');
    Y = get(hs,'YData');
    Z = get(hs,'CData');

    % isolate skull or beam, or keep both
    switch flgDraw
      case 'skull', Z(Z<50) = 0;
      case 'beam', Z(Z>40) = 0;
    end
    
    % initialise a new figure
    hfn = figure('Color','w','Position',[400 400 600 400]);
    
    % set correct printing properties
    % TODO: adjust this based on saving/printing effects
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
    
    % specify number of steps in colormap
    stps = 2^9;
    
    % plot as bitmap or as vector image
    if flgVector
      
      % flip image around X axis
      Z = fliplr(Z);
      
      % expand matrix. This is necessary because the original plot was made
      % using image
      x_step = mode(abs(diff(X)));
      y_step = mode(abs(diff(Y)));
      X = [X(1)-x_step X X(end)+x_step];
      Y = [Y(1)-y_step Y Y(end)+y_step];
      Z = [Z(:,1) Z Z(:,end)];
      Z = [Z(1,:); Z; Z(end,:)];
      
      % draw the contour map
      [~,hn] = contourf(X,Y,Z,stps,'LineStyle','none');

      % set the colormap to the same color resolution
      colormap(flipud(hot(stps)));

      % set the axis
      axis equal;
      %axis([min(X)+x_step/2 max(X)-x_step/2 min(Y)+y_step/2 max(Y)-y_step/2]);
      axis([min(X)+x_step max(X)-x_step min(Y)+y_step max(Y)-y_step]);
      
    else
      
      % redraw the bitmap
      imagesc(X,Y,Z);
      colormap(flipud(hot(stps)));
      axis equal;
      
    end
    
    % make the axes invisible
    han = gca;
    han.Box = 'Off';
    han.Visible = 'Off';

    % set the color bar
    han.CLim = CLim;
    hc = colorbar('eastoutside');
    %hc = colorbar('southoutside');
    hc.FontSize = 18;
    %hc.Box = 'off';
    hc.LineWidth = 0.5;
    hc.TickDirection = 'out';
    hc.Box = 'on';
    hc.Ticks = [];

    % adjust the axis
    han.Color = 'w';
    han.XColor = 'k';
    han.YColor = 'k';
    han.LineWidth = 1.5;
    han.FontSize = 18;

    % add title
    if c == 2
      strTitle = 'axial';
    elseif c == 4
      strTitle = 'coronal';
    elseif c == 6
      strTitle = 'sagittal';
    else
      strTitle = 'oops';
    end
    strTitle = [siteList{s} '_' strTitle];
    ht = title(han,strTitle,'interpreter','none');
    ht.Units = 'normalized';
    ht.Position = [0.5 1.02 0];
    ht.Color = 'k';
    ht.FontSize = 24;
    ht.FontWeight = 'normal';

    % save the figure 
    if flgSave
      figName = fullfile(workDir,strTitle);
      if ismember(flgDraw,{'skull','beam'})
        figName = [figName '_' flgDraw];
      end

      % save as png
      %export_fig([figName '.png'], '-png','-r600','-nocrop', hfn);

      % save a naked png
      ht.Visible = 'off';
      %han.Visible = 'off';
      hc.Visible = 'off';
      if ~flgVector
        export_fig([figName '_naked.png'], '-png','-r600', hfn);
      end
      %han.Visible = 'on';
      hc.Visible = 'on';

      % save the figure as pdf
      if flgVector
        export_fig([figName '_flat.pdf'], '-pdf','-r600','-nocrop', hfn);
        print([figName '.pdf'], '-dpdf', '-r600', hfn);
      end

    end

  end

end
