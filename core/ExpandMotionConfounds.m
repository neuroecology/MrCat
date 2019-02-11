function MC = ExpandMotionConfounds(MC,fnameOut,d)
% ExpandMotionConfounds
% Expands motion confound parameters to capture non-linear effects in a
% poor imitation of a Volterra series.
%   first degree:   [ MC ]
%   second degree:  [ MC MC.^2 deriv1(MC) ]
%   third degree:   [ MC MC.^2 deriv1(MC) MC.^3 deriv2(MC) ]
%
% MC is a (filename pointing to a) T x p matrix
% fnameOut is a path where to save the expansion (leave empty to ignore)
% d sets the Volterra series degree (default: 2)
%--------------------------------------------------------------------------
%
% version history
% 2018-05-01    Lennart created
%
%--------------------------------------------------------------------------

% overhead
if nargin < 3 || isempty(d), d = 2; end
if nargin < 2 || isempty(fnameOut), fnameOut = ''; end

% read in data, if MC is a path
if ischar(MC)
  MC = load(MC);
end

% initialise the first degree (no expansion)
MCorig = MC;
dMC = MC;

% expand up to requested degree
for c = 2:d
  % take the d-degree exponent
  eMC = MCorig.^d;
  % take the derivative
  [~,dMC] = gradient(dMC);
  % put the MC series back together
  MC = [MC eMC dMC];
end

% save the motion parameters
if ~isempty(fnameOut)
  dlmwrite(fnameOut,MC,'delimiter',' ');
end
