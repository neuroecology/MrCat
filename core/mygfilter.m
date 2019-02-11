function y = mygfilter(x,sd,varargin)
% y = mygfilter(x,sd)
%
% Uses FFT() to convolve the data X with a Gaussian filter with standard
% deviation SD.
%
% Inputs:
%   X - N-dimensional data
%  SD - 1xN vector of standard deviations for each dimension of the
%       Gaussian filter
%
% Outputs:
%  Y - N-dimensional filtered data
%
% Options:
%  y = mygfilter(x,sd,pad)
%
%   pads X (and the filter) with PAD(i) additional zeros along the ith
%   dimension -- PAD(i) may correspond, for example, to the standard
%   deviation of the filter to reduce the effect of wrap around. PAD is a
%   1xN vector.

%%%% Error check
if (ndims(x)==2)&&(min(size(x))==1)&&(length(sd)==1)
  % Do nothing
elseif ndims(x)~=length(sd)
  error('??? MYGFILTER: numel(sd) must equal ndims(x).');
end;

%%%% Original size of X
nx = size(x);

%%%% Add extra padding
if nargin>2
  pad = varargin{1};
  if length(pad)~=ndims(x)
    fprintf('ndims(X) = %d but length(pad) = %d.\n',ndims(x),length(pad));
    error('??? MYLFILTER: length(PAD) must equal ndims(X).');
  end;
  x = padarray(x,pad,0,'post');
end;

%%%% Make all dimension sizes odd to prevent phase shift during convolution
padsize = 1 - mod(size(x),2);
if sum(padsize)
  x = padarray(x,padsize,0,'post');
end;

%%%% Make filter
f = mygaussiann(size(x),sd,1);

%%%% Convolve
y = ifftn(fftn(x) .* fftn(f));

%%%% Return data the same size as X
ind = mynroi2ind([ones(1,length(nx)); nx],size(y));
y = reshape(y(ind),nx);
