function [stats,thresh] = ggfit(data,visu)
% function [stats,thresh] = ggfit(data,[visu=0])
%
% Perform Gausssian/gamma mixture modelling on ICA data using FSL's meldoic.
% Adapted from Saad Jbabdi's original version, all credit to him.
%-------------------------------------------------------------------------
%
% Inputs:
%   data    single component data
%   visu    visualize results (1) or not (0)
%
% Outputs:
%   stats
%   thresh  Threshold values for pos and neg gammas based on interactions
%           with noise distribution. Moriarty2 uses third threshold, the
%           median of the positive gamma
%
% version history
% 20032018 Rogier   Cleanup and improved dealing with FSL and temp files
% 16032018 Rogier   Adapted Saad's code for MrCat
%-------------------------------------------------------------------------

if(nargin<2);visu=0;end

data = double(data(:));
N    = length(data);
if(length(data)>32000)
%     n=2^(floor(nextpow2(N)/2));
%     p=2^(ceil(nextpow2(N)/2));
    n=ceil((N+1)/100);
    p=100;
    zdata = zeros(n,p);
    mask  = zeros(n,p);
    zdata(1:N) = data;
    mask(1:N) = 1;
else
    zdata=data;
    mask=ones(size(data));
end

% Get FSL path and set up for melodic
FSLDIR = getenv('FSLDIR');
addpath([FSLDIR '/etc/matlab']);
tmpfile = 'ggfittemp';
saveimgfile(zdata,[tmpfile '.nii.gz'],[1 1 1]);
saveimgfile(mask,[tmpfile '_mask.nii.gz'],[1 1 1]);
mat=rand(numel(zdata),1);
save([tmpfile '_mat.txt'],'mat','-ascii');

% Run melodic
unix([FSLDIR '/bin/melodic -i ' tmpfile ' --ICs=' tmpfile ' --mix=' tmpfile '_mat.txt -o ' tmpfile '_out --Oall -m ' tmpfile '_mask']);

% Load melodic results and determine threshold
s = load([tmpfile '_out/stats/MMstats_1']);

stats.gaussian.mean  = s(1,1);
stats.gaussian.std   = sqrt(s(2,1));
stats.gammapos.shape = abs(s(1,2)^2/s(2,2));
stats.gammapos.scale = abs(s(2,2)/s(1,2));
stats.gammaneg.shape = abs(s(1,3)^2/s(2,3));
stats.gammaneg.scale = abs(s(2,3)/s(1,3));
stats.prop           = s(3,:);

xx = linspace(min(data),max(data),10000);
g1 = normpdf(xx,stats.gaussian.mean,stats.gaussian.std);
g2 = gampdf(xx,stats.gammapos.shape,stats.gammapos.scale);
g3 = gampdf(-xx,stats.gammaneg.shape,stats.gammaneg.scale);

i1 = min(find(stats.prop(2)*g2>stats.prop(1)*g1));
if(isempty(i1));i1=length(xx);end
i2 = max(find(stats.prop(3)*g3>stats.prop(1)*g1));
if(isempty(i2));i2=1;end
thresh1 = [xx(i1) xx(i2)];

i3 = min(find(cumsum(g2)>sum(g2)/2));
if(isempty(i3));i3=length(xx);end
i4 = min(find(cumsum(g3)>sum(g3)/2));
if(isempty(i4));i4=length(xx);end
thresh2=[xx(i3) xx(i4)];

thresh = [thresh2 thresh1];

% Visualize results if so required
if(visu>0)
    xx = linspace(min(data),max(data),100);

    figure,hold on
    [n,x]=hist(data,xx);
    b=bar(x,n/sum(n));
    set(b,'edgecolor',[.8 .8 .8],'facecolor',[.8 .8 .8],'barwidth',1);

    g1 = normpdf(xx,stats.gaussian.mean,stats.gaussian.std);
    g2 = gampdf(xx,stats.gammapos.shape,stats.gammapos.scale);
    g3 = gampdf(-xx,stats.gammaneg.shape,stats.gammaneg.scale);

    gg=stats.prop(1)*g1 + stats.prop(2)*g2 + stats.prop(3)*g3;


    plot(xx,stats.prop(1)*g1/sum(g1),'g','linewidth',2);
    plot(xx,stats.prop(2)*g2/sum(g2),'c','linewidth',2);
    plot(xx,stats.prop(3)*g3/sum(g3),'c','linewidth',2);
    plot(xx,gg/sum(gg),'r','linewidth',2)

    for i=1:length(thresh)
        line([thresh(i) thresh(i)],[0 max(n/sum(n))],'color','k')
        text(thresh(i),1.03*max(n/sum(n)),num2str(thresh(i),2));
    end

end

% Clean up
unix(['rm -r ' tmpfile '*']);