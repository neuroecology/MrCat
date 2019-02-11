function MIGP(datasets,output)
% Peform MIGP group-PCA as described in  as specified in Smith et al. (2014)
% 101:738-749.
%--------------------------------------------------------------------------
%
% Use
%   MIGP({'dataset1',dataset2'},'outputname.mat')
%
% Obligatory inputs:
%   datasets    cell containing strings with full input file names, which
%               can have extensions .nii.gz (NIFTI_GZ), .mat, or .nii
%               (CIFTI)
%   output      string full output file name (.mat)
%
% Requires readimgfile.m
%
% version history
% 2017-02-15    Rogier fixed data load function and variable
% 2016-08-25    Rogier added data reshaping
% 2016-06-22    Rogier bug in data reading fixed
% 2016-04-26    Rogier changed file handling to use readimgfile
% 2016-03-08    Rogier created
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2015-03-08
%--------------------------------------------------------------------------


%==================================================
% Do the work
%==================================================

W=[];
dPCAint=1200;
for i=1:length(datasets)

    fprintf('MrCat MIGP working on dataset %i of %i...\n',i,length(datasets));

    %----------------------------------------------
    % Load data
    %----------------------------------------------

    % fprintf('Loading data...');
    [~,~,ext] = fileparts(datasets{i});
    if isequal(ext,'.mat')
        B = load(datasets{i});
        filetype = 'mat';
    else
        B = readimgfile(datasets{i});
    end

    %----------------------------------------------
    % Change to 2D
    %----------------------------------------------

    datasize = size(B);
    if length(datasize)==2
        % do nothing
    elseif length(datasize)==3
        B = reshape(B,datasize(1)*datasize(2),datasize(3));
    elseif length(datasize)==4
        B = reshape(B,datasize(1)*datasize(2)*datasize(3),datasize(4));
    end

    %----------------------------------------------
    % Regress out mean
    %----------------------------------------------

    % fprintf('Regressing out mean...');
    B=regress_out(B',mean(B)')';
    grot=demean(B');
    W=double([W; demean(grot)]);

    %----------------------------------------------
    % PCA
    %----------------------------------------------

    fprintf('PCA...');
    [uu,dd]=eigs(W*W',min(dPCAint,size(W,1)-1));

    W=uu'*W;

end

dPCA=1000;

%==================================================
% Save output
%==================================================

data=W(1:dPCA,:)'; clear W;
save data data;

if length(datasize)==3
    data = reshape(data,datasize(1),datasize(2),1000);
elseif length(datasize)==4
    data = reshape(data,datasize(1),datasize(2),datasize(3),1000);
end

save(output,'data','-v7.3');
