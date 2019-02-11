%function [betas,pvalues] = spider_regression(fingerprints,names,contrast)
% function [betas,pvalues] spider_regression(fingerprints,names,contrast)
%
% Function to perform a logistic regression on connectivity fingerprints
%--------------------------------------------------------------------------
%
% Inputs:
%   fingerprints    matrix of n_subject,n_dependent_variables,n_independent_variables
%   names           cell structure with names of independent variables
%                   (i.e., target regions)
%   contrast        vector with a 1 and a -1 and for the rest zeros to
%                   indicate which dependent variables you want to test
%
% version history
%   31-07-2018 Rogier   Fixed bug in beta(s) and added plotting of error
%                       bars
%   10-05-2018 Rogier   created
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2015-2018
%-------------------------------------------------------------------------- 

%==================================================
% Housekeeping
%==================================================

% For debugging:
load fingerprints; % assuming input is subjects*dependent*independent
explanatoryvariablenames = {'25','32pl','32d','8m','9mc','9mr','946d','46','45','44','10m','10md','10l','47o','11','11m','13','14m','FOp'};
contrast = [1 -1 0 0 0];
fingerprints = fingerprints(:,:,[1 2 14 16]);
explanatoryvariablenames = {'25','32pl','47o','11m'};

% Normalise the spiders
fingerprints = normalise(fingerprints,3);

% Rename variable
if exist('name','var'), explanatoryvariablenames = names; end

%==================================================
% Create model
%==================================================

X = []; Y = [];
for i = 1:length(contrast)
    if contrast(i)==1
        X = [X; [reshape(fingerprints(:,i,:),size(fingerprints,1),size(fingerprints,3))]];
        Y = [Y; ones(size(fingerprints,1),1)];
    elseif contrast(i)==-1
        X = [X; [reshape(fingerprints(:,i,:),size(fingerprints,1),size(fingerprints,3))]];
        Y = [Y; zeros(size(fingerprints,1),1)];
    end
end
X = normalise(X,1);
figure; subplot(1,2,1); imagesc(X); title('X'); subplot(1,2,2); imagesc(Y); title('Y');

%==================================================
% Explore data
%==================================================

figure; hold on;
for i = 1:size(X,2)
    plot((ones(length(find(Y==1)),1)*i)-.05,X(find(Y==1),i),'rx');
    plot((ones(length(find(Y==0)),1)*i)+.05,X(find(Y==0),i),'bx');
end
xticks([1:size(X,2)]); xticklabels(explanatoryvariablenames);
hold off;

%==================================================
% Do the regression
%==================================================

[B,DEV,STATS] = glmfit(X,Y,'binomial');

figure; hold on;
bar([1:length(B)-1],STATS.beta(2:end));
xticks([1:size(X,2)]); xticklabels(explanatoryvariablenames);
for i = 2:length(STATS.p)
    line([i-1 i-1],[STATS.beta(i)-STATS.se(i) STATS.beta(i)+STATS.se(i)]);
    if STATS.p(i)<0.05, plot(i-1,max(STATS.beta(2:end))*1.2,'k*'); end
end

betas = STATS.beta(2:end);
pvalues = STATS.p(2:end);