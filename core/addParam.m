function p = addParam(p,param,default,expected)
%
% Use
%   p =  addParam(p,param,default,expected)
%
% version history
% 2015-10-23  Rogier    Documentation
% 2015-07-24  Lennart   First published on matlab-public-lennart
%
% copyright
% Lennart Verhagen
% University of Oxford, 2015-10-23
%--------------------------------------------------------------------------

if nargin<4 || isempty(param), expected = {}; end
if ~iscell(param), param = {param}; end
if ~isstruct(expected) && ~iscell(expected), expected = {expected}; end
if iscell(expected) && length(expected)==1
    expected = repmat(expected,size(param));
end

% use different functions depending on matlab version
global matlabversion;
if isempty(matlabversion);
    matlabversion = str2double(regexp(version,'20\d{2}','match','once'));
end

% loop over parameters
for ip = 1:length(param)
    if isstruct(expected)
        if matlabversion<2013
            addParamValue(p,param{ip},default.(param{ip}),@(x) any(validatestring(x,expected.(param{ip}))));
        else
            addParameter(p,param{ip},default.(param{ip}),@(x) any(validatestring(x,expected.(param{ip}))));
        end
    elseif ~isempty(expected) && ~isempty(expected{ip})
        if matlabversion<2013
            addParamValue(p,param{ip},default.(param{ip}),expected{ip});
        else
            addParameter(p,param{ip},default.(param{ip}),expected{ip});
        end
    else
        if matlabversion<2013
            addParamValue(p,param{ip},default.(param{ip}));
        else
            addParameter(p,param{ip},default.(param{ip}));
        end
    end
end