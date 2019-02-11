% pimp the intensity plots
workDir = '~/projects/lennart/fun/deepFUN/figures2/fig1/simulations';
siteList = {'ACC','amygdala'};
nSite = numel(siteList);

% save or not to save
flgSave = false;

% loop over figures
for s = 1:nSite

  % load the pressure/temperature map;
  importdata(fullfile(workDir,['Isppa ' siteList{s} ' brain only 2.fig']));
  hf = gcf;

  % bring the color bar to the right
  for c = 1:2:6
    % right
    hf.Children(c).Location = 'eastoutside';
    % bottom
    %hf.Children(c).Location = 'southoutside';
  end

%   % transpose the sagittal and coronal slices
%   switch siteList{s}
%     case 'ACC', cTransposeList = [4 6];
%     case 'amygdala', cTransposeList = [2 6];
%   end
%   for c = cTransposeList
%     ha = hf.Children(c);
%     X = ha.Children(1).XData;
%     Y = ha.Children(1).YData;
%     Z = ha.Children(1).CData;
%     % swap the X and Y
%     ha.Children(1).XData = Y;
%     ha.Children(1).YData = X;
%     %ha.Children(1).CData = rot90(ha.Children(1).CData);
%     ha.Children(1).CData = ha.Children(1).CData';
%     axis(ha,'equal');
%     %axis(ha,'tight');
%   end

  % CLim hack
  CLim = [3 6];

  % rescale the temperature plots
  for c = 2:2:6
    ha = hf.Children(c);
    hs = ha.Children(1);

    % store the color scale
    %CLim = ha.CLim;
    ha.CLim = CLim;

    % HACK
    continue

    % extract data
    X = get(hs,'XData');
    Y = get(hs,'YData');
    Z = get(hs,'CData');

    % expand matrix. This is necessary because the original plot was made
    % using image
    x_step = mode(abs(diff(X)));
    y_step = mode(abs(diff(Y)));
    X = [X(1)-x_step X X(end)+x_step];
    Y = [Y(1)-y_step Y Y(end)+y_step];
    Z = [Z(:,1) Z Z(:,end)];
    Z = [Z(1,:); Z; Z(end,:)];

    % specify number of steps in colormap
    stps = 2^9;

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

    % draw the contour map
    [~,hn] = contourf(X,Y,Z,stps,'LineStyle','none');

    % set the colormap to the same color resolution
    colormap(flipud(hot(stps)));

    % set the axis
    axis equal;
    %axis([min(X)+x_step/2 max(X)-x_step/2 min(Y)+y_step/2 max(Y)-y_step/2]);
    axis([min(X)+x_step max(X)-x_step min(Y)+y_step max(Y)-y_step]);
    han = gca;

    % set the color bar
    han.CLim = CLim;
    hc = colorbar('eastoutside');
    %hc = colorbar('southoutside');
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
      strTitle = 'axial';
    elseif c == 4
      strTitle = 'coronal';
    elseif c == 6
      strTitle = 'sagittal';
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

end
