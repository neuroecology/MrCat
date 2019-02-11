function data_CC = ap_calculateCC(data,varargin)
% Function to calculate cross-correlation matrix for clustering externally
% for easier data checking and debugging. In addition, this function will
% run some checks on the data and the CC to improve clustering behavior.
%--------------------------------------------------------------------------
% NOTE: To be used with a clustering algorithm that can handle negative
% correlation coefficient values
%--------------------------------------------------------------------------
%
% Use
%   ap_calculate(data)
%   ap_calculate(data,'plot_CC','no')
%
% Obligatory input:
%   data        data matrix
%
% Optional inputs (using parameter format):
%   plot_CC     'yes' (default) or 'no' 
%
% Output
%   data_CC     cross-correlation matrix of dimensionality column*column of
%               the data matrix
%
% version history
% 2017-06-06    suhas   adapted for AP-clustering, which can handle
%                       negative correlation coefficients
% 2016-03-05	Rogier  created km_calculateCC (for k-means)
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2016
%--------------------------------------------------------------------------

%==================================================
% Housekeeping
%==================================================

% Defaults
plot_CC = 'yes';

if nargin>1
    for vargnr = 2:2:length(varargin)
        switch varargin{vargnr-1}
            case 'plot_CC'
                plot_CC = varargin{vargnr};
        end
    end
end

%==================================================
% Perform data checks
%==================================================

% Check for NaNs
if ~isempty(find(isnan(data(:)),1))
    error('Error in MrCat:ap_calculateCC: data matrix contains NaNs!'); 
end

% Check for zero columns
if sum(~any(data))>0
    error('Error in MrCat:ap_calculateCC: one or more columns in data contains only zeros. This will create NaNs in CC!');
end

%==================================================
% Do the work
%==================================================

data_CC = corrcoef(data);
clear data;

%==================================================
% Perform check of cross-correlation matrix
%==================================================

% Plot correlation coefficients
if strcmp(plot_CC,'yes')
        figure; 
        imagesc(data_CC); 
        title('correlation coefficients'); 
        colorbar;
end

% Check for NaNs
if ~isempty(find(isnan(data_CC(:)),1))
    error('Error in MrCat:ap_calculateCC: cross-correlation matrix contains NaNs!'); 
end