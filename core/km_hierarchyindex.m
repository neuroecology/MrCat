function [HI,varargout] = km_hierarchyindex(idx,varargin)
% Computers hierarchy index for clustering solutions as described in Kahnt
% et al. (2012) J Neurosci
%--------------------------------------------------------------------------
%
% Use
%   [HI,varargout] = km_hierarchyindex(idx,nperm)
%
% Input
%   idx     Vectors with indices of cluster solutions
%
% Optional
%   nperms  Number of random permutations to compare the HI to (pass 0 to
%           ignore)
%   savefig string with figure basenames if saving is required
%
% Output
%   HI                  Vector of HI for each solution
%   Subsequent output   Vector of random permutation solutions
%
% version history
% 2016-03-06  Rogier    tidied up plotting and added optional saving of fig
% 2015-09-16  Lennart	documentation
% 2014-12-01  Lennart   speeded up code
% 2014-02-05  Rogier    created
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2014-02-05
%--------------------------------------------------------------------------

%===============================
%% housekeeping
%===============================

nperms = 0;
savefig = [];

% Optional inputs
if nargin>2
    for vargnr = 2:2:length(varargin)
        switch varargin{vargnr-1}
            case 'nperms'
                nperms = varargin{vargnr};
            case 'savefig'
                savefig = varargin{vargnr};
        end
    end
end

%===============================
%% Calculate HI
%===============================

% variables:
%   i   cluster index at the current level
%   j   custer index at the previous level

idx = [ones(size(idx,1),1) idx];

HI = nan(1,size(idx,2)-1);
ncluster = max(idx,[],1);
for i = 2:size(idx,2)
    j = i-1;

    % create x (matrix whose elements reflect nr of voxels in cluster i
    % coming from cluster j)
    x = nan(ncluster(i),ncluster(j));
    for xi = 1:ncluster(i)
        for xj = 1:ncluster(j)
            x(xi,xj) = sum((idx(:,i)==xi).*(idx(:,j)==xj));
        end
    end

    % Check that x is the right size
    if ~(size(x,1)==max(idx(:,i))) || ~(size(x,2)==max(idx(:,j))), error('Error: x of wrong size in km_hierarchyindex.m!'); end

    % Calculate HI(k)
    HI(j) = sum(max(x,[],2)./sum(x,2)) / ncluster(i);

end

%===============================
%% Random permutations (if requested)
%===============================

if nperms>0, fprintf('Hierarchy index: random permutations...\n'); end

HIrandperm = nan(nperms,length(HI));
for permutnr = 1:nperms

    for k = 1:size(idx,2)
        idx(:,k) = randomize_vector(idx(:,k));
    end

    for i = 2:size(idx,2)
        j = i-1;

        % create x (matrix whose elements reflect nr of voxels in cluster i
        % coming from cluster j)
        x = nan(ncluster(i),ncluster(j));
        for xi = 1:ncluster(i)
            for xj = 1:ncluster(j)
                x(xi,xj) = sum((idx(:,i)==xi).*(idx(:,j)==xj));
            end
        end

        % Check that x is the right size
        if ~(size(x,1)==max(idx(:,i))) || ~(size(x,2)==max(idx(:,j))), error('Error: x of wrong size in km_hierarchyindex.m!'); end

        % Calculate HI(k)
        HIrandperm(permutnr,j) = sum(max(x,[],2)./sum(x,2)) / ncluster(i);

    end

end

varargout{1} = mean(HIrandperm,1);

%===============================
%% Plot results
%===============================

h = figure; hold on; title('Hiearchy index');
set(gca,'XTick',[1:length(HI)],'XTickLabel',[1:length(HI)]+1); xlim([0.5 length(HI)+.5]);
plot(1:length(HI),HI,'o');
if nperms>0, plot(1:length(HI),varargout{1},'*'); legend('HI','Random permuation');
else legend('HI');
end
hold off;

if ~isempty(savefig)
    saveas(h,[savefig 'hierarchyindex.jpg']);
end
