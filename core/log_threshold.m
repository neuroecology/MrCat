function out = log_threshold(data,perc_threshold)
% Log transform all data > 0, normalize by dividing by the maximum value,
% and zero everything < perc_threshold
%--------------------------------------------------------------------------
%
% Use
%   out = log_threshold(data,perc_threshold)
%
% Input
%   data            the data to log transform
%   perc_threshold  a value between 0 and 1, so cutting off the bottom
%                   five percent values happens when 0.05 is passed
%
% Output
%   out             the log transformed data
%
% version history
% 2015-10-13 Rogier     Better dealing with values of 0
% 2015-09-16	Lennart		documentation
% 2013-05-16  Rogier    Changed order to: log transform, normalize, thresh
% 2013-05-10  Rogier    clean-up and documentation
% 2013-05-10  Rogier    Added data normalization by dividing by max value
% 2013-05-09  Rogier    Thresholding now based on max value
% 2013-03-22  Rogier    created
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2013-03-22
%--------------------------------------------------------------------------


% visualisation flag for debugging
vizdata = 0;

if vizdata==1, figure; subplot(1,4,1); hist(data(find(data(:)>0))); end


%===============================
%% Log transform
%===============================

if min(data(:))<0, error('Error in MrCat:log_threshold.m: Min data value < 0!'); end

data = data + 1;
data = log(data);


if vizdata==1, subplot(1,4,2); hist(data(find(data(:)>0))); end


%===============================
%% Normalize (divide by maximum value)
%===============================

maxvalue = max(data(:));
data(find(data>0)) = data(find(data>0))./maxvalue;
clear maxvalue;

if vizdata==1, subplot(1,4,3); hist(data(find(data(:)>0))); end


%===============================
%% Threshold
%===============================

maxvalue = max(data(:));
cutoff = perc_threshold*maxvalue;
data(find(data<cutoff)) = 0;

if vizdata==1, subplot(1,4,4); hist(data(find(data(:)>0))); end

out = data;
%--------------------------------------------------------------------------


%===============================
%% Legacy version
%===============================
%
% data(find(data>0)) = log(data(find(data>0)));
% logdata = sort(log(data(find(data>0))));
%
% % % Based on length data
% % cutoff = round(length(logdata)*perc_threshold);
% cutoff = logdata(cutoff);
% data(find(data<cutoff)) = 0;
%
% out = data;
