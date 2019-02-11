function output = partialcorrmatrix(varargin)
% function output = partialcorrmatrix(varargin)
%
% Calculates the partialcorrelation between all columns in an input matrix,
% controlling for all the other columns and optional confounds in a separate
% matrix.
%--------------------------------------------------------------------------
%
% varargin inputs:
%   If one input:       observations*variables data matrix
%   If two inputs:      observations*variables data matrix and observations*confounds
%                       confound matrix
%   If three inputs:    observations*1 data vector, observations*variables
%                       data matrix to calculate correlations with first
%                       vector, and observations*confounds confound matrix.
%                       Note that if this option is used without confounds,
%                       an empty confounds matrix must be given
%
% Output:
%   output          variables*variables partial correlation matrix

% version history
% 06052012 RBM Added empty confounds if only one input
% 02082013 RBM Added three input option
% 11122012 RBM created
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2015-03-08
%-------------------------------------------------------------------------- 

%=====================================================
% Housekeeping
%=====================================================

if nargin == 1
    
    data = varargin{1};
    confounds = [];
    
elseif nargin == 2
    
    data = varargin{1};
    confounds = varargin{2};
    
    if size(data,1)~=size(confounds,1), error('Error: number of observations in data and confound matrices not the same!'); end
    
elseif nargin == 3
    
    data_vector = varargin{1};
    data = varargin{2};
    confounds = varargin{3};
    
    if size(data_vector,1)~=size(data,1), error('Error: number of observations in data_vector and data not the same!'); end
    if ~isempty(confounds)
        if size(data_vector,1)~=size(confounds,1), error('Error: number of observations in data_vector and confounds not the same!'); end
        if size(data,1)~=size(confounds,1), error('Error: number of observations in data and confounds not the same!'); end
    end
    
else
    
    error('Error: Incorrect number of input arguments!');
    
end

%=====================================================
% Do the work
%=====================================================

% Note: this function calls partialcorr, information on which appears below:
% RHO = partialcorr(X,Z) returns the sample linear partial correlation
% coefficients between pairs of variables in X, controlling for the
% variables in Z. X is an N-by-P matrix, and Z an N-by-Q matrix, with rows
% corresponding to observations, and columns corresponding to variables. RHO
% is a symmetric P-by-P matrix.

if nargin==1 || nargin==2
    
    %------------------------------------------------------
    % One or two input arguments use
    %------------------------------------------------------
    
    output = zeros(size(data,2),size(data,2));
    
    for c1 = 1:size(data,2)
        
        for c2 = 1:size(data,2)
            
            % Get current data and confounds
            curr_data = [data(:,c1) data(:,c2)];
            curr_confounds = [data confounds]; curr_confounds(:,[c1 c2]) = [];
            
            % Calculate partial correlation
            partialcorrelation = partialcorr(curr_data,curr_confounds);
            
            % Housekeeping
            output(c1,c2) = partialcorrelation(1,2); output(c2,c1) = partialcorrelation(1,2);
            
        end
        
    end
    
elseif nargin==3
    
    %------------------------------------------------------
    % Three input arguments use
    %------------------------------------------------------
    
    for c1 = 1:size(data,2)
        
        % Get current data and confounds
        curr_data = [data_vector data(:,c1)];
        curr_confounds = [data confounds]; curr_confounds(:,c1) = [];
        
        % Calculate partial correlation
        partialcorrelation = partialcorr(curr_data,curr_confounds);
        
        % Housekeeping
        output(1,c1) = partialcorrelation(1,2);
        
    end
    
end