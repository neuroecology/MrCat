function [p_value,results] = perm_results(stats,varargin)
% function [p_value,results] = perm_results(stats,varargin)
%
% Assign p-value to the results of a simple permutation test
%
% Obligatory input:
%   stats   vector of statistics of the different permutations, first one
%           is assumed to be the actual data
%
% Optional inputs (using parameter format):
%   side   'right-side' (default) or 'left-side'
%   alpha   value of alpha, 0.05 default
%   toplot  'yes' or 'no' (default)
%
% Determine p-value for permutation testing
%
% verion history:
% 2018-05-12  Lennart   refactoring and documentation
% 2018-05-12  Lennart   speed and accuracy improvements
% 10-05-2016 RBM cleaned up plotting
% 29-04-2016 RBM fixed bugs dealing with left and right-sidedness
% 28-04-2016 RBM created
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2016-04-28
%--------------------------------------------------------------------------

%==================================================
% Housekeeping
%==================================================

% Defaults
side = 'right-side';
alpha = 0.05;
toplot = 'no';

if nargin>1
  for vargnr = 2:2:length(varargin)
    switch varargin{vargnr-1}
      case 'side'
        side = varargin{vargnr};
      case 'alpha'
        alpha = varargin{vargnr};
      case 'toplot'
        toplot = varargin{vargnr};
    end
  end
end

% test if the statistics toolbox is on the path
if exist('prctile','file') == 2
  flgToolboxStats = true;
else
  flgToolboxStats = false;
end


%==================================================
% Determine p-value and signifance
%==================================================

% sign-flip statistic based on the tail of the test
if strcmpi(side,'left-side')
  stats = -stats;
end

% retrieve the observed statistic
actual_stat = stats(1);

% retrieve p-value
p_value = sum(actual_stat<=stats)/numel(stats);
    
% retrieve criterion
if flgToolboxStats
  criterion = prctile(stats,100*(1-alpha));
else
  % use alternative when statistics toolbox is not available
  sorted_stats = sort(stats);
  criterion = sorted_stats(round(length(sorted_stats)*(1-alpha)));
end
    
% sign-flip statistic back to the original sign if needed
if strcmpi(side,'left-side')
  stats = -stats;
  actual_stat = -actual_stat;
  criterion = -criterion;
end

% report in results structure
if p_value < alpha
  results.significance = 'Significant';
else
  results.significance = 'Not significant';
end
results.p_value = p_value;
results.actual = actual_stat;
results.criterion = criterion;


%==================================================
% Plot
%==================================================

switch toplot
  case 'yes'
    myfig = figure; [myhist,myx] = hist(stats,25); bar(myx,myhist); hold on;
    
    cl = line([results.criterion results.criterion],[0 max(myhist)+1]); set(cl,'color','b');
    dl = line([actual_stat actual_stat],[0 max(myhist)+1]); set(dl,'color','r');
    legend('Perm data','Criterion','Actual data');
    
    
    title('Permutation results');
    hold off;
  case 'no'
    % do nothing
end
