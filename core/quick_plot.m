function quick_plot(data_file, hemi, fig_name)
% Makes matlab plots for quick reference.
% Not completely functional on cluster. But works locally.
% -------------------------------------------------------------------------
% Usage: cd to results directory or provide full path 
% quick_plot('clusters_2.func.gii', 'L', 'clusters_2_filename.png')
% -------------------------------------------------------------------------
% NOTE: Plots are on "generic/universal" hemi.surf.gii files, provided with the CIFTIMatlabReaderWriter_old toolbox.
% No responsibility taken for misinterpretation of results.
% -------------------------------------------------------------------------
    close all % Closes all other figures.

    addpath(genpath('~/code/MrCat-dev'))

    % Get generic image file.
    if ~isempty(hemi)
        [path_toolbox,~,~] = fileparts(which('create_func_gii'));
        if upper(hemi)=='L'
            surf = gifti([path_toolbox filesep 'L.surf.gii']);
        elseif upper(hemi)=='R'
            surf = gifti([path_toolbox filesep 'R.surf.gii']);
        else
            error('Invalid definition of hemisphere. Allowed inputs: L or R')
        end
    end

    data = gifti(data_file);

    % Plot (not-so-nice) figures
    figure
    fig = gcf;
    fig.Position = [100, 100, 1000, 400];
    fig.Color = 'black';
    fig.InvertHardcopy = 'off';

    subplot(1,2,1);
    plot(surf, data);
    view(-90,0)

    subplot(1,2,2);
    plot(surf, data);
    view(90,0)

    thisfig = getframe(gcf);
    imwrite(thisfig.cdata, fig_name);

end
