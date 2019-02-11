function CC = km_calculateCC(data,varargin)
% Function to calculate cross-correlation matrix for clustering externally
% for easier data checking and debugging. In addition, this function will
% run some checks on the data and the CC to improve clustering behavior
%--------------------------------------------------------------------------
%
% Use
%   km_calculate(data)
%   km_calculate(data,'plot_data','yes')
%
% Obligatory input:
%   data        data matrix
%
% Optional inputs (using parameter format):
%   plot_data   'yes' or 'no' (default)
%   plot_CC     'yes' or 'no' (default)
%
% Output
%   CC          cross-correlation matrix of dimensionality column*column of
%               the data matrix
%
% version history
% 2016-03-05	Rogier  created
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2016
%--------------------------------------------------------------------------

%==================================================
% Housekeeping
%==================================================

% Defaults
plot_data = 'no';
plot_CC = 'no';

if nargin>1
    for vargnr = 2:2:length(varargin)
        switch varargin{vargnr-1}
            case 'plot_data'
                plot_data = varargin{vargnr};
            case 'plot_CC'
                plot_CC = varargin{vargnr};
        end
    end
end

%==================================================
% Perform data checks
%==================================================

% Plot data
switch plot_data
    case 'yes'
        figure; imagesc(data); title('Data'); colorbar;
end

% Check for NaNs
if length(find(isnan(data(:))))>0, error('Error in MrCat:km_calculateCC: cross-correlation matrix contains NaN!'); end

% Check for zero columns
if sum(~any(data))>0, error('Error in MrCat:km_calculateCC: one or more columns in data contains only zeros. This will create NaNs in CC!'); end

%==================================================
% Do the work
%==================================================

CC = 1 + corrcoef(data);
clear data;

%==================================================
% Perform check of cross-correlation matrix
%==================================================

% Plot CC
switch plot_CC
    case 'yes'
        figure; imagesc(CC); title('CC'); colorbar;
end

% Check for NaNs
if length(find(isnan(CC(:))))>0, error('Error in MrCat:km_calculateCC: cross-correlation matrix contains NaN!'); end