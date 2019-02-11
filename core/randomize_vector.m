function output = randomize_vector(input)
%
% function output = randomize_vector(input)
%
% This is a recreation of the famous randomize_vector.m, it randomises the
% order of items in a vector
%
% Rogier B. Mars, University of Oxford, 09112012

if size(input,1)>size(input,2)
    orientation = 'vertical';
elseif size(input,2)>size(input,1)
    orientation = 'horizontal';
end

switch orientation
    case 'vertical'
        input = [input randperm(size(input,1))'];
        input = sortrows(input,2);
        output = input(:,1);
    case 'horizontal'
        input = [input' randperm(size(input,2))'];
        input = sortrows(input,2);
        input = input(:,1);
        output = input';
end