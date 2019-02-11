function H = columnentropy(data,varargin)
% Calculate the entropy of the columns of a matrix in bits. By default,
% this function assumes that you are passing vectors elements. If you want
% to pass a vector of (marginal) probabilites, add the optional parameter
% 'datatype' as 'probabilities'.
%--------------------------------------------------------------------------
%
% Use
%   H = columnentropy(data)
%   H = columnentropy(data,'datatype','elements')
%
% Input
%   data      data matrix
%
% Optional (parameter-value pairs)
%   datatype  'elements' (default) or 'probabilities'
%
% Output
%   H         entropy in bits
%
% version history
% 2015-09-16	Lennart		documentation
% 2014-03-09  Rogier    Added option to pass probability matrix
% 2014-02-05  Rogier    created
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2014-02-05
%--------------------------------------------------------------------------


%===============================
%% housekeeping
%===============================

% Defaults
datatype = 'elements';

if nargin>1
    for argnr = 2:2:nargin
        switch varargin{argnr-1}
            case 'datatype'
                datatype = varargin{argnr};
        end
    end
end


%===============================
%% Do the work
%===============================

switch datatype
    case 'elements'

        %-------------------------------
        % If working with element input matrix
        %-------------------------------

        elements = unique(data)';
        for d = 1:size(data,2)

            % Get frequencies
            P = [];
            for i = 1:length(elements)

                e = elements(i);
                P(i) = length(find(data(:,d)==e))/size(data,1);

            end

            % Calculate entropy
            H(d) = -sum(P.*log2(P));

        end

    case 'probabilities'

        %-------------------------------
        % If working with probability matrix
        %-------------------------------

        for d = 1:size(data,2)

            P = data(:,d);

            % Calculate entropy
            H(d) = -sum(P.*log2(P));

        end

end
