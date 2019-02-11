function data = binarize(varargin)
% funtion data = binarize(varargin)
% Binarize (a la fslmaths -bin), potentially threshold first
%--------------------------------------------------------------------------
%
% Binarize. Two input option:
%   1 input     Input will be the data matrix to binarize. The absolute of
%               all values will be used and binarized. This functionality
%               is similar to FSL's binarize option
%   3 inputs    Inputs will be the data matrix, the criterion, and the
%               inclusiveness ('discard' so the criterion value will be
%               returned 0, 'keep' so the criterion value will be returned
%               1).
%
% 20160413 RBM MrCat compatible
% 22042012 RBM Added inclusiveness feature
% 18022013 RBM Added 1 input FSL-like feature
% 18022013 RBM Created
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2016-04-13
%--------------------------------------------------------------------------

%===============================================
% Housekeeping
%===============================================

if nargin == 1
    data = varargin{1};
elseif nargin == 3
    data = varargin{1};
    criterion = varargin{2};
    inclusiveness = varargin{3};
    
else
    
    error('Error: Incorrect number of input arguments!');
    
end

%===============================================
% Do the work
%===============================================

if nargin == 1
    
    data = abs(data);
    data(find(data>0))=1;
    data(find(data<=0))=0;
    
elseif nargin == 3
    
    if criterion<0, error('Error: criterion<0 will result in massive shit!'); end
    
    switch inclusiveness
        
        case 'discard';
            
            data(find(data<=criterion))=0;
            
            data(find(data>criterion))=1;
            
        case 'keep'
            
            data(find(data<criterion))=0;
            data(find(data>=criterion))=1;
    end
    
end