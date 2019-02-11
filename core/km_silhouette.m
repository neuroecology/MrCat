function km_silhouette(idxx,X,varargin)
% Evaluate range of kmeans solutions using Matlab's silhouette
%--------------------------------------------------------------------------
%
% Use
%   km_silhouette(idxx,X)
%   km_silhouette(idxx,X,'savefig','~/myfig','savesilh','~/mymat')
%
% Input
%   idxx        voxels*number_of_solutions cluster index matrix
%   X           data matrix submitted to kmeans
%
% Optional (parameter-value pairs)
%   'savefig'   followed by a string with figure basenames
%   'savesilh'  followed by a string with basename to save silhouette
%               values to *.mat file
%
% Output
%   none        results are reported in figures
%
% version history
% 2016-03-06  Rogier    minor change to deal with output dirs of kmeans_fdt
% 2015-09-16  Lennart   documentation
% 2014-11-24  Rogier    Added varargin options to save fig and silh values
% 2014-02-25  Rogier    created
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2014-02-25
%--------------------------------------------------------------------------


%===============================
%% housekeeping
%===============================

savefig = [];
savesilh = [];

% Optional inputs
if nargin>2
    for vargnr = 2:2:length(varargin)
        switch varargin{vargnr-1}
            case 'savefig'
                savefig = varargin{vargnr};
            case 'savesilh'
                savesilh = varargin{vargnr};
        end
    end
end


%===============================
%% Do the work
%===============================

nsolutions = size(idxx,2);

h = figure; hold on; plotnr = 1;

for cc = 1:size(idxx,2)

    fprintf('Silhouette: %i clusters...\n',max(idxx(:,cc)));
    subplot(ceil(nsolutions/3),3,plotnr);
    [silh,h] = silhouette(X,idxx(:,cc),'sqeuclid');
    set(get(gca,'Children'),'FaceColor',[.8 .8 1])
    xlabel('Silhouette Value');
    ylabel('Cluster');
    title([num2str(max(idxx(:,cc))) ' cluster solution']);
    plotnr = plotnr + 1;

    allsilh{cc} = silh;
    % save allsilh allsilh

end

if ~isempty(savefig)
    saveas(h,strcat(savefig, 'silhouette_plots.jpg'));
end
if ~isempty(savesilh)
    save(strcat(savesilh, 'silhouette_values.mat'),'allsilh');
end

hold off;


%===============================
%% Report group measures
%===============================

for cc = 1:size(idxx,2)
    meansilh(cc) = mean(allsilh{cc});
end
h = figure; plot([max(idxx(:,1)):max(idxx(:,size(idxx,2)))],meansilh);
if ~isempty(savefig)
    saveas(h,strcat(savefig, 'mean_silhouette_value_plot.jpg'));
end
