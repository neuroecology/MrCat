function sortedCC = sort_CC_matrix(CC,idxr,idxc,toplot,str_title)
% sort a cross-correlation matrix based on correlation strength
%--------------------------------------------------------------------------
%
% Use
%   sortedCC = sort_CC_matrix(CC,idxr,idxc,toplot,str_title)
%
% Input
%   CC      cross-correlaton matrix
%   idxr    indices for the rows
%   toplot  plot results (1), plot and save results (2), or not (0)
%
% Optional
%   CC      correlaton matrix
%   idxr    indices for the rows
%   idxc    indices for the columns
%   toplot  plot results (1), plot and save results (2), or not (0)
%   str_title   Figure title
%
% Output
%   sortedCC  the sorted cross-correlation matrix
%
% version history
% 2015-09-16	Lennart		documentation
% 2014-04-01  Lennart   housekeeping
% 2014-01-16  Rogier    Added figure title input option
% 2013-11-05  Rogier    Changed handling to deal with non-square CC matrix
% 2013-11-05  Rogier    Fixed bug in plotting sortedCC
% 2013-08-28  Rogier    Added option to save the plot
% 2013-08-27  Rogier    Added five input options to set title of plot
% 2013-08-25  Rogier    Allowing for separate row and column sorting
% 2013-08-25  Rogier    created
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2013-08-25
%--------------------------------------------------------------------------


%===============================
%% Housekeeping
%===============================

% check input arguments
narginchk(3,5);

if nargin == 3
    toplot = idxc;
    idxc = [];
end
if nargin < 5
    str_title = 'Sorted_matrix';
end


%===============================
%% Sort
%===============================

% Sort in one dimension (rows)
t = [CC idxr];
t = sortrows(t,size(t,2));
t = t(:,1:end-1);

% Sort in second dimension (columns)
if ~isempty(idxc)
    t2 = [t' idxc];
    t2 = sortrows(t2,size(t2,2));
    t2 = t2(:,1:end-1);
    t2 = t2';
elseif isempty(idxc)
    t2 = t;
end

sortedCC = t2;


%===============================
%% Plot
%===============================

if toplot==1 || toplot==2

    h = figure;

    subplot(11,11,[1 12 23 34 45 56 67 78 89 100]);
    imagesc(sort(idxr)); set(gca,'xtick',[]); set(gca,'xticklabel',[]); set(gca,'ytick',[]); set(gca,'yticklabel',[]);

    subplot(11,11,[2:11 13:22 24:33 35:44 46:55 57:66 68:77 79:88 90:99 101:110]);
    imagesc(sortedCC); set(gca,'xtick',[]); set(gca,'xticklabel',[]); set(gca,'ytick',[]); set(gca,'yticklabel',[]);
    title(str_title,'Interpreter','none');

    subplot(11,11,[112:121]);
    imagesc(sort(idxc)'); set(gca,'xtick',[]); set(gca,'xticklabel',[]); set(gca,'ytick',[]); set(gca,'yticklabel',[]);

end
if toplot==2
    saveas(h,strcat(str_title,'.jpg'));
end
