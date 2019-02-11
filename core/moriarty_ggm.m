function moriarty_ggm(ICAsurface,ICAvolume,volume_standard,outputbase,varargin)
% function moriarty_ggm(ICAsurface,ICAvolume,volume_standard,outputbase,varargin)
%
%
% Perform Guassian/gamma mixture modelling on moriarty output using melodic
%-------------------------------------------------------------------------
%
% Obligatory input:
%   ICAdata     string containing ICA results from moriarty2
%   outputbase  string containing output base
%
% Optional inputs (using parameter format):
%   visualize   visualize output (1) or not (0, default)
%
% Calls: ggfit.m
%
% version history
% 05072018 Rogier   Fix: transposing icasig when saving dtseries makes a
%                   difference
% 23032018 Rogier   Changed output name convention
% 20032018 Rogier   Created
%
% copyright
% Rogier B. Mars, University of Oxford, 20032018
%-------------------------------------------------------------------------

%=============================================================
%% House keeping
%=============================================================

visualize = 0;
hemi = 'L';

% Optional inputs
if nargin>2
    for vargnr = 2:2:length(varargin)
        switch varargin{vargnr-1}
            case 'visualize'
                visualize = varargin{vargnr};
            case 'hemi'
                hemi = varargin{vargnr};
        end
    end
end

%=============================================================
%% Do the work
%=============================================================

%-------------------------------------------------------------
% Surface
%-------------------------------------------------------------

fprintf('MrCat:moriarty_ggm: working on surface...\n');

% Load data
load(ICAsurface);

% Gaussian/gamma mixture modeling
thresholds_surface = [];
for i=1:size(icasig,1)
    [stats{i},thresh{i}] = ggfit(icasig(i,:),visualize);
    icasig(i,find(icasig(i,:)<thresh{i}(3))) = 0;
    thresholds_surface(i) = thresh{i}(3);
end

% Save
saveimgfile(icasig',[outputbase '_ICAsurfacethresholded.dtseries.nii'],hemi);
% save([outputbase '_ICAsurfacethresholds'],'thresholds_surface','-v7.3');
% save([outputbase '_ICAsurfacethresholded'],'icasig','-v7.3');

%-------------------------------------------------------------
% Volume
%-------------------------------------------------------------

fprintf('MrCat:moriarty_ggm: working on volume...\n');

% Load data
load(ICAvolume);
[standard,~,stdhdr] = readimgfile(volume_standard);

% Gaussian/gamma mixture modeling
thresholds_volume = [];
for i = 1:size(beta_tracks,1)
    [stats{i},thresh{i}] = ggfit(beta_tracks(i,:),visualize);
    beta_tracks(i,find(beta_tracks(i,:)<thresh{i}(3))) = 0;
    thresholds_volume(i) = thresh{i}(3);
end

% Save
tract4D = [];
for i = 1:size(icasig,1)
   
    % volume
    tractvolume = zeros(length(standard(:)),1);
    tractvolume(find(binarize(standard(:))==1),1) = beta_tracks(i,:)';
    tractvolume = reshape(tractvolume,size(standard,1),size(standard,2),size(standard,3));
    tract4D(:,:,:,i) = tractvolume;
end

disp('saving');
saveimgfile(tract4D,[outputbase '_ICAvolumethresholded.nii.gz'],stdhdr.pixdim(2:4)');
% save([outputbase '_ICAvolumethresholded'],'tract4D','-v7.3');
% save([outputbase '_ICAvolumethresholds'],'thresholds_volume','-v7.3');

fprintf('Done!\n');