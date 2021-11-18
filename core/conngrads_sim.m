function S = conngrads_sim( M,method )
% Creates similarity matrix from fdt_matrix2
%--------------------------------------------------------------------------
%
% Use
%   sim_mat = conngrads_sim(M,method)
% 
%
% Obligatory inputs:
%   M       data matrix (seed voxels  * target voxels)
% 
%   
%   method           pick from one of the following (default eta2):
%       eta2          use similarity measure proposed in: 
%                    Cohen AL, Fair DA, Dosenbach NUF, et al. Defining 
%                    Functional Areas in Individual Human Brains using 
%                    Resting Functional Connectivity MRI. NeuroImage. 
%                    2008;41(1):45-57. doi:10.1016/j.neuroimage.2008.01.066.   
%       pearson     pearson correlation (bear in mind this gives positive and 
%                   negative values which have to be taken into account
%                   before continuing
%       cc          matrix times transpose (with this type of data -visitations we can
%                   only obtain positive values)
%
% Output
%   sim_mat   similarity matrix
%
% version history
% 2019-05-09   Rogier    Minor doc update (variable names)
% 2017-02-06   Guilherme Created  
%
% copyright
% Guilherme Blazquez Freches
% Donders Institute, 2017-02-06

%===============================

% Do the work
%===============================
switch method
    case 'cc'
        S = conngrads_cc(M);
    case 'pearson'
        S = conngrads_ps(M); 
    case 'eta2'
        S = conngrads_eta2(M);   
end

end

