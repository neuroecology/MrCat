function jointPs = get_jointprobs(data)
% function jointPs = get_jointprobs(data)
%
% Calculate joint probabilties across two vectors of matrix data
%
% Input:
%   data    number_of_elements*2 matrix of elements
%
% Rogier B. Mars, University of Oxford, 27022014

%=========================================================
% Housekeeping
%=========================================================

if size(data,2)~=2, error('Error: size(data,2) incorrect in get_jointprobs.m!'); end

elementsA = unique(data(:,1));
elementsB = unique(data(:,2));

%=========================================================
% Do the work
%=========================================================

% Get joint probabilities
jointPs = zeros(length(elementsA),length(elementsB));
for i = 1:size(data,1)
    jointPs(find(data(i,1)==elementsA),find(data(i,2)==elementsB)) = jointPs(find(data(i,1)==elementsA),find(data(i,2)==elementsB)) + 1;
end
jointPs = jointPs/size(data,1);
% jointPs = jointPs(:)