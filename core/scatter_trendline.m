function plot_trendline(regressor,data)
% function plot_trendline(regressor,data)
%
% Create scatter plot and linear trendline
%--------------------------------------------------------------------------
%
% Use:
%   plot_trendline(regressor,data)
%   plot_trendline(design_matrix(:,2),data_vector)
%
% version history
% 23052017 RBM renamed to scatter_trendline
% 06022017 RBM created
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2017-0206
%--------------------------------------------------------------------------

scatter(regressor,data);
hold on ;
my_poly=polyfit(regressor,data,1);

Xrange = [min(regressor):(max(regressor)-min(regressor))*.1:max(regressor)];
fit=polyval(my_poly,Xrange);

plot(Xrange,fit,'r');