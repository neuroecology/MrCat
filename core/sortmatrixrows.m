function output = sortmatrixrows(data,order)

output = [data order];
output = sortrows(output,size(output,2));
output = output(:,1:size(output,2)-1);