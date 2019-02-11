function glass(data,brain,varargin)
% Produce SPM-like glass brain projection. Assumes the glass brain and the
% data are in the same space. Data will be normalized using normalize0. Now
% in color, upgrading its predecessor glass_projection.m.
% Note that when images are FSL .nii.gz images read in using read_avw, this
% function will display results in radiological convention
%--------------------------------------------------------------------------
%
% Use
%   glass(data,brain)
%   glass(data,brain,varargin)
%
% Input
%   data        3D matrix
%   brain       3D matrix containing brain to be used for creating glass brain
%
% Optional (parameter-value pairs)
%   orientation 'data' (default) or 'flipx'
%   colmap      colormap to use for data (default: 'Autumn'), use flipud(gray)
%               for white background and gray colors
%   bgcolor     background color (default: [.3 .3 .3])
%   braincolor  color for brain outline (default: [.8 .8 .8])
%
% Output
%   none        results are reported in a figure or saved to disk
%
% version history
% 04-06-2018  Rogier    created
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2018
%--------------------------------------------------------------------------

%===============================
% Housekeeping
%===============================

if ~isempty(data) && ~isequal(size(data),size(brain)), error('Error in MrCat:glass: inputs not of the same size!'); end

orientation = 'data';
colmap = 'Autumn';
bgcolor = [.3 .3 .3];
braincolor = [.8 .8 .8];

% Optional inputs
if nargin>2
    for vargnr = 2:2:length(varargin)
        switch varargin{vargnr-1}
            case 'orientation'
                orientation = varargin{vargnr};
            case 'colormap'
                colmap = varargin{vargnr};
            case 'bgcolor'
                bgcolor = varargin{vargnr};
            case 'braincolor'
                braincolor = varargin{vargnr};
        end
    end
end

brain = binarize(brain,0,'discard');

% Determine size and location of subfigures
Pix_SS = get(0,'screensize');
u = round(Pix_SS(3)/5);
h1pos = [round(Pix_SS(3)/2-(u*1.5)) round(Pix_SS(4)/2-u*0.5) u u];
h2pos = [round(Pix_SS(3)/2-(u*.5)) round(Pix_SS(4)/2-u*0.5) u u];
h3pos = [round(Pix_SS(3)/2+(u*.5)) round(Pix_SS(4)/2-u*0.5) u u];

%===============================
% Sagittal
%===============================

h1=figure; set(h1,'Position',h1pos); % [365 400 250 250]); % 365 715 1065, 400

glass_sag = max(brain,[],1);
glass_sag = reshape(glass_sag,size(glass_sag,2),size(glass_sag,3));
glass_sag = (glass_sag);
glass_sag = edge(glass_sag);
[x,y] = ind2sub(size(glass_sag),find(glass_sag));

data_sag = max(data,[],1);
data_sag = reshape(data_sag,size(data_sag,2),size(data_sag,3));
data_sag = rot90(data_sag);

ax1 = axes; imagesc(ax1,data_sag);
ax2 = axes; scatter(x,y,10,braincolor,'.');
linkaxes([ax1,ax2])
ax1.Visible = 'off';
ax2.Visible = 'off';
ax1.XTick = [];
ax1.YTick = [];
ax2.XTick = [];
ax2.YTick = [];
cm = colormap(colmap); cm = [bgcolor ; cm];
colormap(ax1,cm)
colormap(ax2,flipud(gray))

%===============================
% Coronal
%===============================

h2=figure; set(h2,'Position',h2pos); % [715 400 250 250]); % 365 715 1065, 400

glass_cor = max(brain,[],2);
glass_cor = reshape(glass_cor,size(glass_cor,1),size(glass_cor,3));
glass_cor = (glass_cor);
glass_cor = edge(glass_cor);

data_cor = max(data,[],2);
data_cor = reshape(data_cor,size(data_cor,1),size(data_cor,3));
data_cor = rot90(data_cor);

switch orientation
    case 'data'
        [x,y] = ind2sub(size(glass_cor),find((glass_cor)));
    case 'flipx'
        [x,y] = ind2sub(size(glass_cor),find(flipud((glass_cor))));
        data_cor = fliplr(data_cor);
end

ax1 = axes; imagesc(ax1,data_cor);
ax2 = axes; scatter(x,y,10,braincolor,'.');
linkaxes([ax1,ax2])
ax1.Visible = 'off';
ax2.Visible = 'off';
ax1.XTick = [];
ax1.YTick = [];
ax2.XTick = [];
ax2.YTick = [];
cm = colormap(colmap); cm = [bgcolor ; cm];
colormap(ax1,cm)
colormap(ax2,flipud(gray))

%===============================
% Axial
%===============================

h3=figure; set(h3,'Position',h3pos); % [1065 400 250 250]); % 365 715 1065, 400

glass_axial = max(brain,[],3);
glass_axial = (glass_axial);
glass_axial = edge(glass_axial);

data_axial = max(data,[],3);
data_axial = rot90(data_axial);

switch orientation
    case 'data'
        [x,y] = ind2sub(size(glass_axial),find(glass_axial));
    case 'flipx'
        [x,y] = ind2sub(size(glass_axial),find(flipud(glass_axial)));
        data_axial = fliplr(data_axial);
end

ax1 = axes; imagesc(ax1,data_axial);
ax2 = axes; scatter(x,y,10,braincolor,'.');
linkaxes([ax1,ax2])
ax1.Visible = 'off';
ax2.Visible = 'off';
ax1.XTick = [];
ax1.YTick = [];
ax2.XTick = [];
ax2.YTick = [];
cm = colormap(colmap); cm = [bgcolor ; cm];
colormap(ax1,cm)
colormap(ax2,flipud(gray))

%%

% figure;
% % subplot(1,3,1);
% 
% ax1 = axes;
% %[x,y,z] = peaks;
% %surf(ax1,x,y,z)
% 
% glass = readimgfile('/Users/rmars/code/MrCat-dev/data/chimpanzee/Chimplate/ChimpYerkes29_AverageT1w_restore_brain_15mm.nii.gz');
% glass = binarize(glass,0,'discard');
% glass_sag = max(glass,[],1);
% glass_sag = reshape(glass_sag,size(glass_sag,2),size(glass_sag,3));
% glass_sag = rot90(glass_sag);
% glass_sag = edge(glass_sag);
% % %scatter(ax1,rand(10,1),rand(10,1));
% % % imagesc(ax1,glass_sag);
% % colormap(ax1,flipud(gray));
% 
% [x,y] = ind2sub(size(rot90(rot90(rot90((glass_sag))))),find(rot90(rot90(rot90(glass_sag)))));
% 
% volumedata = readimgfile('../look_at_moriarty_results/chimp_LR_take4b_allsubjects_50ICs_ICAtracts.nii.gz');
% data = volumedata(:,:,:,1);
%  data_sag = max(data,[],1);
%     data_sag = reshape(data_sag,size(data_sag,2),size(data_sag,3));
%     data_sag = rot90(data_sag);
% 
% % view(2)
% % ax2 = axes;
% % imagesc(ax2,data_sag)
% % % Link them together
% % linkaxes([ax1,ax2])
% % % Hide the top axes
% % ax2.Visible = 'off';
% % ax2.XTick = [];
% % ax2.YTick = [];
% % % Give each one its own colormap
% % colormap(ax1,flipud(gray))
% % colormap(ax2,'cool')
% % % % Then add colorbars and get everything lined up
% % % %set([ax1,ax2],'Position',[.17 .11 .685 .815]);
% % % %cb1 = colorbar(ax1,'Position',[.05 .11 .0675 .815]);
% % % %cb2 = colorbar(ax2,'Position',[.88 .11 .0675 .815]);
% 
% figure;
% 
% subplot(1,3,1);
% ax1 = axes; imagesc(ax1,data_sag);
% ax2 = axes; scatter(x,y,10,[.8 .8 .8],'.');
% % Link them together
% linkaxes([ax1,ax2])
% % Hide the top axes
% ax2.Visible = 'off';
% ax2.XTick = [];
% ax2.YTick = [];
% % Give each one its own colormap
% cm = colormap('Autumn'); cm = [.3 .3 .3 ; cm];
% colormap(ax1,cm)
% colormap(ax2,flipud(gray))