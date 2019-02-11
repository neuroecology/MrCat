function output = normalize1(input)
%
% function output = normalize1(input)
%
% Normalizes a vector or 2D or 3D matrix so that all values are beteen -1 and 1
%
% Based: http://stackoverflow.com/questions/4684622/matlab-how-to-normalize-denormalize-a-vector-to-range-11
%
% Rogier B. Mars, University of Oxford, 09082012
%   19012013 RBM Updated to handle 1, 2, and 3D matrices

%==========================================
% Housekeeping
%==========================================

if length(size(input))==1, dims = 1;
elseif length(size(input))==2, dims = 2;
elseif length(size(input))==3, dims = 3;
else error('Error: input matrix of dimensionality that is not supported!');
end

%==========================================
% Do the work
%==========================================

switch dims
    case 1
        
        %# get max and min
        maxVec = max(input);
        minVec = min(input);
        
        %# normalize to -1...1
        output = ((input-minVec)./(maxVec-minVec) - 0.5 ) *2;
        
        % %# to "de-normalize", apply the calculations in reverse
        % vecD = (vecN./2+0.5) * (maxVec-minVec) + minVec
        
    case 2
        
        % Get original size
        origsize = size(input);
        
        % Reshape
        input = input(:);
        
        %# get max and min
        maxVec = max(input);
        minVec = min(input);
        
        %# normalize to -1...1
        output = ((input-minVec)./(maxVec-minVec) - 0.5 ) *2;
        
        % Reshape back
        output = reshape(output,origsize(1),origsize(2));
        
    case 3
        
        % Get original size
        origsize = size(input);
        
        % Reshape
        input = input(:);
        
        %# get max and min
        maxVec = max(input);
        minVec = min(input);
        
        %# normalize to -1...1
        output = ((input-minVec)./(maxVec-minVec) - 0.5 ) *2;
        
        % Reshape back
        output = reshape(output,origsize(1),origsize(2),origsize(3));
end