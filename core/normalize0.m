function output = normalize0(input)
% function output = normalize0(input)
%
% As normalize1.m, but returning vector normalized between 0 and 1 instead
% of between -1 and 1.
%
% Rogier B. Mars, University of Oxford, 31012013
% 28032013 RBM Adapted to suit both 2D and 3D matrices

orig_size = size(input);

input = input(:);
output = ((input-min(input))./(max(input)-min(input)));

% Reshape back to input format
if length(orig_size)==2
    output = reshape(output,orig_size(1),orig_size(2));
elseif length(orig_size)==3
    output = reshape(output,orig_size(1),orig_size(2),orig_size(3));
else
    error('Input matrices of this size are currenlty not supported!');
end