function [ eta2 ] = conngrads_eta2( data )
% Creates similarity matrix from fdt_matrix2 using formula by Cohen et al.
% (2008)
%
% Use
%   eta2 = conngrads_eta(M)
% 
%
% Obligatory inputs:
%   data       data matrix (seed voxels  * target voxels)
% 
% Output
%   eta2   similarity matrix (Cohen et al. (2008))
% 
%version history
% 2019-11-15   Guilherme made code more efficient
% 2019-10-21   Rogier    commented out automatic plotting and logical test
%                        for symmetry
% 2019-05-09   Rogier    Minor doc update (variable names)
% 2017-02-06   Guilherme Created  
%
% copyright
% Guilherme Blazquez Freches
% Donders Institute, 2017-02-06


%==================================================
% Do the work
%==================================================

eta2=zeros(size(data,1),size(data,1)); %% Output - similarity matrix. 1-Totally similar, 0-Totally dissimilar

for i=1:size(eta2,1)
    for j=i:size(eta2,2)
        mi = (data(i,:)+data(j,:))./2; 
        mm = mean(mi);
        ssw = sum(power(data(i,:)-mi,2) + power(data(j,:)-mi,2));
        sst = sum(power(data(i,:)-mm,2) + power(data(j,:)-mm,2));
        eta2(i,j) = 1-ssw/sst;
    end
end
eta2=eta2+eta2';
eta2=eta2-eye(size(eta2,1));
end

