function moriarty2(fdt_matrix2,varargin)
% function moriarty2(fdt_matrix2,varargin)
%
%
% Perform MIGP and FASTICA on tractography data based on the (correct) pseudo-code
% in the appendix of O'Muircheartaigh & Jbabdi (2017, NeuroImage)
%-------------------------------------------------------------------------
%
% Obligatory input:
%   fdt_matrix2   String contining fdt_matrix2 file (note: the variable
%                 contained in there is assumed to be called avgmat)
%
% Optional inputs (using parameter format):
%   nICs          Number of independent components
%   dPCA          Dimensionality of the PCA
%   outputbase    String containing output base (default: pwd and 'moriarty')
%   skipMIGP      String containing PCA output file to feed directly into
%                 fastICA
%   skipICA       String containing ICA output file to feed directly into
%                 postprocessing
%   skipGMM       Empty matrix (default) or 'yes'
%
% version history
% 27092018 Rogier    Added variance explained evaluation
% 21032018 Rogier    Moved GGM to separate function
% 20032018 Rogier    Added skip GGM option
% 16032018 Rogier    Added gg mixture modelling and skipICA option
% 08032018 Rogier    Deal with multiple fdt_matrix2 variable names
% 07022018 Rogier    Added skipMIGP option
% 22012017 Rogier    NComps error cleanup
% 16012017 Rogier    Added FASTICA path call
% 11012017 Rogier    Clean-up for MrCat-dev
% 24122017 Rogier    Created
%
% copyright
% Rogier B. Mars, University of Oxford, 24122027
%-------------------------------------------------------------------------

%=============================================================
%% House keeping
%=============================================================

NComps = 50; %Dimensionality of the ICA and PCA fed into fastica
dPCA=4000; %Dimensionality of the PCA
outputbase = 'moriarty';
skipMIGP = [];
skipICA = [];

% Optional inputs
if nargin>2
    for vargnr = 2:2:length(varargin)
        switch varargin{vargnr-1}
            case 'nICs'
                NComps = varargin{vargnr};
            case 'dPCA'
                dPCA = varargin{vargnr};
            case 'outputbase'
                outputbase = varargin{vargnr};
            case 'skipMIGP'
                skipMIGP = varargin{vargnr};
            case 'skipICA'
                skipICA = varargin{vargnr};
            case 'skipMMG'
        end
    end
end

%=============================================================
%% Load and prepare data
%=============================================================

% C is seed*voxel and standardized to 0 mean and unit std long the voxel dim

fprintf('LOADING DATA...\n');
load(fdt_matrix2);
if exist('avgmat','var'), C = avgmat; clear avgmat;
elseif exist('data','var'), C = data; clear data;
else error('Error in MrCat:moriarty2: fd_matrix2 variable name unknown!');
end
fprintf('fdt_matrix2 is of size %i by %i\n',size(C,1),size(C,2));

N=size(C,2); %Number of voxels total
order=randperm(N); %Randomise order for MIGPPCA
C_random=C(:,order);

fprintf('NORMALIZING DATA...\n');
for i = 1:size(C,2)
    C(:,i) = normalise(C(:,i),1);
end

%=============================================================
%% MIGP bit
%=============================================================

if isempty(skipMIGP)

    fprintf('MIGP...\n');
    n=10000; % Number of voxels to reduce at each iteration
    W=[];
    totalis = ceil(N/n); cnt=1;
    for i=1:n:N
        fprintf('MIGP iteration %i of %i\n',cnt,totalis);
        data=C_random(:,i:min(i+n-1,N))'; %Select data
        W=[W; data];
        [U,D]=eigs(W*W',min(dPCA,size(W,1)-1)); %Get the top eigenvectors of W
        W=U'*W; %Multiply these into W to get weighted eigenvectors
        cnt = cnt + 1;
        % size(W)
    end
    data=W(1:dPCA,:);

    % save('/vol/neuroecology-scratch/rbmars/threespeciesPCA/GroupPCA_Diff_2.mat','data','-v7.3');
    save([outputbase '_PCA'],'data','-v7.3');

elseif ~isempty(skipMIGP)

    fprintf('Skipping MIGP, loading existing PCA results...\n');
    clear data; load(skipMIGP);

end

%=============================================================
%% FASTICA bit
%=============================================================

if isempty(skipICA)

    fprintf('FASTICA...\n');

    MRCATDIR = getenv('MRCATDIR');
    addpath(genpath([MRCATDIR '/external/FASTICA_25']));

    [icasig] = fastica(data, 'lastEig', NComps,'numOfIC',NComps,'approach','symm','g','pow3','finetune','pow3');

    % save('/vol/neuroecology-scratch/rbmars/threespeciesPCA/GroupICA_Diff_2.mat','icasig','-v7.3');
    save([outputbase '_ICA'],'icasig','-v7.3');

elseif ~isempty(skipICA)

    fprintf('Skipping ICA, loading existing ICA results...\n');
    load(skipICA);

end

%=============================================================
%% Evaluating
%=============================================================

fprintf('Evaluation...\n');

% back_proj = A*S;

percent_variance_explained = 100*(1-mean(var(data - A*icasig))/mean(var(data)));

save([outputbase '_ICApercvarexplained'],'percent_variance_explained','-v7.3');


%=============================================================
%% post-processing
%=============================================================

fprintf('POST-PROCESSING...\n');

% Force the ica components to be positive on the long tail
for i=1:size(icasig,1)
    if ((prctile(icasig(i,:),1)+prctile(icasig(i,:),99.5))<0)
        icasig(i,:)=icasig(i,:)*-1;
    end
end

save([outputbase '_ICApos'],'icasig','-v7.3');

% Use linear regression of the spatial ICs  (in seed space) to get their representation in tractography space
beta_tracks = pinv(icasig')*C;

save([outputbase '_beta_tracks'],'beta_tracks','-v7.3');

fprintf('Done!\n');
