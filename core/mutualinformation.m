function I = mutualinformation(data)
% Calculate the mutual information between the two columns of data
%--------------------------------------------------------------------------
%
% Use
%   I = mutualinformation(data)
%
% Input
%   data 	elements*2 data matrix
%
% Ouput
%   I 		mutual information
%
% Dependency
%   columnentropy.m
%   jointentropy.m
%
% Version history
% 2015-09-16 Rogier Prepared for GitHub
%
% Copywright%
% Rogier B. Mars
% University of Oxford & Donders Institute, 2014-02-06
%--------------------------------------------------------------------------

% Old way of doing stuff:
% js = zeros(length(elementsA),length(elementsB));
% for i = 1:size(js,1)
%     for j = 1:size(js,2)
%         js(i,j) = jointPs(i,j)/(PA(i)*PB(j));
%     end
% end
% js = js(:);
% jointPs = jointPs(:);
% 
% J = jointPs.*log2(js);
% J(isnan(J)) = 0; % Remove effects of joint probabilities of zero
% I = sum(J);

%=========================================================
% Housekeeping
%=========================================================

if size(data,2)~=2, error('Error in MrCat:mutualinformation: size(data,2) incorrect in mutualinformation.m!'); end

%=========================================================
% Do the work
%=========================================================

I = columnentropy(data(:,1)) + columnentropy(data(:,2)) - jointentropy(data);