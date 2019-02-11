function look_at_moriarty(cfg)
% function look_at_moriarty(cfg)
%
% Visualize and write out results of moriarty.m
%-------------------------------------------------------------------------
%
% Obligatory inputs:
%   cfg.volume_tract_file   String containing nICs*target beta_tracks .mat file
%                           from moriarty2.m
%   cfg.surface_tract_file  String containing nICs*seeds .mat file from
%                           moriarty.m
%   cfg.volume_standard     String containing volume file for plotting
%   cfg.surface_standard    String containing .surf.gii for plotting (left hemi
%                           in case of LR)
%   cfg.tract_space_coords_for_fdt_matrix2 String containing this file
%
% Optional input (using parameter format):
%   cfg.outputbase          String containing output base (default: pwd and 'moriarty_')
%   cfg.hemi                Hemisphere used ('R', 'L', 'LR',  default: 'L')
%   cfg.glassprojection     'yes' (default) or 'no'
%   cfg.volumeexclude       String containing volume exclusion mask
%
% version history
% 14052018 Rogier   Changed volume output to work with
%                   tract_space_coords_for_fdt_matrix2 (Note: moriarty_ggm
%                   functionality removed!), changed input to struct,
%                   added ex/inclusion options, and log output
% 27042018 Rogier   Use saveimgfile instead of create_func_gii
% 23032018 Rogier   Added functionality to deal with moriarty_ggm output
% 20032018 Rogier   Improved LR functionality when writing out results
% 12032018 Rogier   Added fslcpgeom for FSLeyes compatibility
% 09030218 Rogier   Added LR functionality
% 23022018 Rogier   Added glasprojection as option and volume hard
%                   parcellation
% 16012018 Rogier   Added volume save and dtseries
% 12012018 Rogier   Created
%
% copyright
% Rogier B. Mars, University of Oxford, 12012018
%-------------------------------------------------------------------------

%=============================================================
%% House keeping
%=============================================================

% load('beta_tracks_2.mat'); % nICs*target
% load('groupICApos_Diff_2.mat'); % icasig nICs*seeds
% standard = readimgfile('/usr/local/fsl/data/standard/MNI152_T1_2mm_brain.nii.gz');
% surface = readimgfile('Q1-Q6_R440.L.inflated.32k_fs_LR.surf.gii');

FSLDIR = getenv('FSLDIR');

% Obligatory inputs
if isfield(cfg,'volume_tract_file'), volume_tract_file = cfg.volume_tract_file; else error('Error in MrCat:look_at_moriarty: volume_tract_file not defined!'); end
if isfield(cfg,'surface_tract_file'), surface_tract_file = cfg.surface_tract_file; else error('Error in MrCat:look_at_moriarty: surface_tract_file not defined!'); end
if isfield(cfg,'volume_standard'), volume_standard = cfg.volume_standard; else error('Error in MrCat:look_at_moriarty: volume_standard not defined!'); end
if isfield(cfg,'surface_standard'), surface_standard = cfg.surface_standard; else error('Error in MrCat:look_at_moriarty: surface_standard not defined!'); end
if isfield(cfg,'tract_space_coords_for_fdt_matrix2'), tract_space_coords_for_fdt_matrix2 = cfg.tract_space_coords_for_fdt_matrix2; else error('Error in MrCat:look_at_moriarty: tract_space_coords_for_fdt_matrix2 not defined!'); end

% Optional inputs
if isfield(cfg,'outputbase'), outputbase = cfg.outputbase; else outputbase = 'moriarty'; end
if isfield(cfg,'hemi'); hemi = cfg.hemi; else hemi = 'L'; end
if isfield(cfg,'glassprojection'); glassprojection = cfg.glassprojection; else glassprojection = 'yes'; end
if isfield(cfg,'volumeexclude'); volumeexclude = cfg.volumeexclude; else volumeexclude = []; end
if isfield(cfg,'volumeinclude'); volumeinclude = cfg.volumeinclude; else volumeinclude = []; end

% % Optional inputs
% if nargin>4
%     for vargnr = 2:2:length(varargin)
%         switch varargin{vargnr-1}
%             case 'outputbase'
%                 outputbase = varargin{vargnr};
%             case 'hemi'
%                 hemi = varargin{vargnr};
%             case 'glassprojection'
%                 glassprojection = varargin{vargnr};
%         end
%     end
% end

%=============================================================
% Load data
%=============================================================

load(volume_tract_file);
if exist('beta_tracks','var') % Output from moriarty2.m
    % do nothing
elseif exist('tract4D','var') % Output from moriarty_ggm.m (deprecated)
    beta_tracks = tract4D; clear tract4D;
end
load(surface_tract_file);
[standard,~,stdhdr] = readimgfile(volume_standard);

%=============================================================
% Plot and save volume results
%=============================================================

load(tract_space_coords_for_fdt_matrix2);
tract4D = zeros(size(standard));
for i = 1:size(tract_space_coords_for_fdt_matrix2,1)
    for j = 1:size(beta_tracks,1)
        tract4D(tract_space_coords_for_fdt_matrix2(i,1)+1,tract_space_coords_for_fdt_matrix2(i,2)+1,tract_space_coords_for_fdt_matrix2(i,3)+1,j) = beta_tracks(j,i);
    end
end

% Glass projection
switch glassprojection
    case 'yes'
        for j = 1:size(beta_tracks,1)
            glass_projection(tract4D(:,:,:,j),standard,'colormap',flipud(gray));
        end
end

% Exclusion (for saving and hp only)
if ~isempty(volumeexclude)
    volumeexclude = readimgfile(volumeexclude);
    for j = 1:size(tract4D,4)
        vol = tract4D(:,:,:,j); vol(find(volumeexclude>0)) = 0;
        tract4D(:,:,:,j) = vol;
    end
    clear vol;
end

% for i = 1:size(icasig,1)
%
%     % volume
%     if length(size(beta_tracks))==2 % Output from moriarty2.m
%         tractvolume = zeros(length(standard(:)),1);
%         tractvolume(find(binarize(standard(:))==1),1) = beta_tracks(i,:)';
%         tractvolume = reshape(tractvolume,size(standard,1),size(standard,2),size(standard,3));
%     elseif length(size(beta_tracks))==4 % Output from moriarty_ggm.m
%         tractvolume = beta_tracks(:,:,:,i);
%     end
%     if isequal(glassprojection,'yes')
%         glass_projection(tractvolume,standard,'colormap',flipud(gray));
%     end
%     tract4D(:,:,:,i) = tractvolume;
% end

saveimgfile(tract4D,[outputbase '_ICAtracts.nii.gz'],stdhdr.pixdim(2:4)');

% Hard parcellation
unix([FSLDIR '/bin/fslmaths ' [outputbase '_ICAtracts'] ' -Tmaxn ' [outputbase '_hardparcellation']]);
if ~isempty('volumeinclude')
    unix([FSLDIR '/bin/fslmaths ' [outputbase '_hardparcellation'] ' -mas ' volumeinclude ' ' [outputbase '_hardparcellation']]);
end

%=============================================================
% Surface hard parcellation
%=============================================================

for i = 1:size(icasig,2)
    hardparcellation(i) = find(icasig(:,i)==max(icasig(:,i)));
end

switch hemi
    case 'L'
        saveimgfile(hardparcellation',[outputbase '_hardparcellation.func.gii'],hemi);
    case 'R'
        saveimgfile(hardparcellation',[outputbase '_hardparcellation.func.gii'],hemi);
    case 'LR'
        saveimgfile(hardparcellation(1:length(hardparcellation)/2)',[outputbase '_hardparcellation_L.func.gii'],'L');
        saveimgfile(hardparcellation((length(hardparcellation)/2)+1:length(hardparcellation))',[outputbase '_hardparcellation_R.func.gii'],'R');
end

%=============================================================
%% Save surface results
%=============================================================

% Create .dtseries.nii
mat2dtseries(icasig',[outputbase '_ICAtracts'],hemi);

% Create .spec
wb_command = getenv('wb_command');
switch hemi
    case 'L'
        saveimgfile(icasig',[outputbase '_ICAtracts.func.gii'],hemi);
        create_spec_file([outputbase '_spec.spec'],...
            hemi,'SURFACE',surface_standard,...
            hemi,'METRIC',[outputbase '_hardparcellation.func.gii']);
        cmd = [wb_command ' -add-to-spec-file ' [outputbase '_spec.spec CORTEX_LEFT '] [outputbase '_ICAtracts.dtseries.nii']];
        unix(cmd);
    case 'R'
        saveimgfile(icasig',[outputbase '_ICAtracts.func.gii'],hemi);
        create_spec_file([outputbase '_spec.spec'],...
            hemi,'SURFACE',surface_standard,...
            hemi,'METRIC',[outputbase '_hardparcellation.func.gii']);
        cmd = [wb_command ' -add-to-spec-file ' [outputbase '_spec.spec CORTEX_RIGHT '] [outputbase '_ICAtracts.dtseries.nii']];
        unix(cmd);
    case 'LR'
        create_spec_file([outputbase '_spec.spec'],...
            'L','SURFACE',surface_standard,...
            'R','SURFACE',strreplace(surface_standard,'.L.','.R.'),...
            'L','METRIC',[outputbase '_hardparcellation_L.func.gii'],...
            'R','METRIC',[outputbase '_hardparcellation_R.func.gii']);
        cmd = [wb_command ' -add-to-spec-file ' [outputbase '_spec.spec CORTEX '] [outputbase '_ICAtracts.dtseries.nii']];
        unix(cmd);
end

%=============================================================
% Save surface results
%=============================================================

save([outputbase '_log.mat'],'cfg');