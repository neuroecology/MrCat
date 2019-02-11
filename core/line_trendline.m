function line_trendline(data)
% function line_trendline(data)

% d = load('tseries.txt');
% d = d(10:end);
x = [1:length(data)]';

myfit = polyfit(x,data,1);
trendline = myfit(1).*x + myfit(2);

plot(x,data,'b'); hold on; plot(x,trendline,'r'); hold off;