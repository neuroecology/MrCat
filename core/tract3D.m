function [hf,S,T,L] = tract3D(varargin)
% Display probabilistic tracts and structural images in 3D
%--------------------------------------------------------------------------
%
% Use
%   tract3D('Tract','default','Struc','default','Param','Value')
%
% Input
%   Tract       name of the probtrack path image to plot (.nii.gz)
%   Struc       name of the structural image to plot onto (.nii.gz)
%
% Optional (parameter-value pairs)
%   Handle      figure or plot handle
%   DrawStruc   boolean to draw structural image if it exists [true] or a
%               structure with settings (see below)
%   DrawTract   boolean to draw probtrack image if it exists [true] or a
%               structure with settings (see below)
%   DrawLight   boolean to draw viewing and lighting options [true] or a
%               structure with settings (see below)
%   GetDrawSet  'struc', 'tract', 'light', 'none' ['none']
%               If any other value than 'none' this function will output
%               the current settings to draw the requested section and
%               return immediately (without plotting). These settigns will
%               be stored in a structure which can be adapted and used as
%               input for any of the 'Draw...' parameters.
%   Remove      remove the following handles
%
% Output
%   hf      figure handle
%   S       structure describing structural background image
%   T       structure describing tracts
%   L       strcuture describing viewing and lighting options
%
%
% Input structures
%-------------------------------
% Structural (settings for drawing a structural image)
%   S.draw          boolean, draw the structural or not [true]
%   S.flipLR        boolean, flip the brain left-right [false]
%   S.surf.vol      specification for the volume to draw used as input for
%                   W = subvolume(x,y,z,S.img,S.surf.vol)
%               1. coordinates: [nan nan 50 140 nan nan]
%               2. a string to evaluate: '[S.ymid S.ymax nan nan nan nan]'
%               3. a string: 'brain', 'none', 'hemileft', 'hemiright'
%   S.surf.thr      threshold for the isosurface [400]
%   S.surf.reduce   vertex reduction ratio: 0 or input to reducepatch [0.5]
%   S.surf.color    color specification of the surface [0.7 0.7 0.7]
%   S.cut.vol       specification for the cut to draw: see S.surf.vol
%                   a cut defines the limits of the surf subvolume and can
%                   have multiple slices, a slice is just that, a slice.
%   S.cut.thr       see S.surf.thr [200]
%   S.cut.alpha     alpha value of the cut [1]
%   S.slice.cor.vol 	empty, scalar, or array for multiple [100]
%   S.slice.cor.thr 	see S.surf.thr [S.surf.thr]
%   S.slice.cor.alpha alpha value of the slice [0.8]
%   S.slice.sag.vol 	empty, scalar, or array for multiple [] (not drawn)
%   S.slice.sag.thr 	see S.surf.thr [S.surf.thr]
%   S.slice.sag.alpha alpha value of the slice [0.8]
%   S.slice.ax.vol  	empty, scalar, or array for multiple [50]
%   S.slice.ax.thr    see S.surf.thr [S.surf.thr]
%   S.slice.ax.alpha 	alpha value of the slice [0.8]
%   S.colormap      	colormap ['gray']
%   S.CLim          	color limits of the axis [0 1000];
%
% Tract (settings for drawing the tracts)
%   T.draw          boolean, draw the tracts or not [true]
%   T.flipLR        boolean, flip the tract image left-right [false]
%   T.thr           one or multiple values to threshold the volume, either
%                   directly related to the volume intensity or as
%                   percentiles between 0 and 100; default: [95 90]
%   T.thrtype       type of threshold: 'auto', 'regular', 'prc' ['auto']
%                   if T.thr>=1 & T.thr<100, then 'auto' sets type to 'prc'
%   T.alpha         alpha values for each threshold [1 0.2 0.1]
%   T.color         color labels, indices, or RGB values for each tract
%   T.smooth.mode  	smooth the data: 'gaussian', 'box', 'none' ['gaussian']
%   T.smooth.kernel	3D smoothing kernel [3 3 3]
%
% Light (settings for the lighting and view point)
%   L.draw          set (add) lightning and viewing [true]
%   L.daspect       axis scaling ratio [1 1 1]
%   L.axis          axis display ['tight']
%   L.view          camera point [0 20]
%   L.camzoom       camera zoom [1.4]
%   L.camproj       camera projection ['perspective']
%   L.light         add light point(s) by specifying inputs for light [{}]
%   L.lightangle    add light point(s) using inputs for lightangle [{}]
%   L.camlight      add camera light(s) [{'right','left'}]
%   L.lighting      specs for light bouncing of objects ['gouraud']
%   L.material      shininess of objects 'default' 'shiny' 'metal' ['dull']
%
%-------------------------------
%
% DEVELOPMENT IDEAS:
%   - properly allow for cell entries as Tract and Struc
%   - remove small patch volumes of the tracts
%       - either by multiplying the tract by a smoothed binary mask at the
%         desidred isosurface threshold. Prehaps patches to ignore should
%         not be set to 0, but to a value just below the threshold.
%       - or loop over all patches and calculate the volume of each
%         self-contained component and threshold. Probably too slow
%  - do some hole filling after thresholding the structural, or use a brain
%    mask to get the structural
%
%
% version history
% 2015-09-16	Lennart		documentation
% 2015-09-16  Lennart   added lightangle, added 'mni' option for Struc
% 2015-09-14  Lennart   swapped x and y dimensions to match MRI convention
% 2015-09-14  Lennart   now plotting images in mm not vox
% 2015-03-11  Lennart   brought threshold, alpha, and color to Tract
% 2015-03-11  Lennart   added documentation on the input structures
% 2015-02-23	Lennart   changed lighting, slice, and cut options
% 2015-02-17	Lennart   created
%
% copyright
% Lennart Verhagen & Rogier B. Mars
% University of Oxford & Donders Institute, 2015-02-01
%--------------------------------------------------------------------------


%===============================
%% housekeeping
%===============================

% parse input arguments based on input, default and expected values
p = inputParser;
p.KeepUnmatched = true;
addParameter(p,'Tract','',@(x) ischar(x) || iscell(x));
addParameter(p,'Struc','',@(x) ischar(x) || iscell(x));
addParameter(p,'Handle',[],@(x) ishandle(x) || isnumeric(x));
addParameter(p,'DrawStruc',true,@(x) islogical(x) || isstruct(x));
addParameter(p,'DrawTract',true,@(x) islogical(x) || isstruct(x));
addParameter(p,'DrawLight',true,@(x) islogical(x) || isstruct(x));
addParameter(p,'GetDrawSet','none',@(x) any(validatestring(lower(x),{'struc','tract','light','none'})));
addParameter(p,'Remove',[],@(x) iscell(x) || ishandle(x));
parse(p,varargin{:});

% retrieve input arguments from inputParser object
FnameTract	= p.Results.Tract;
FnameStruc 	= p.Results.Struc;
hf        	= p.Results.Handle;
DrawStruc  	= p.Results.DrawStruc;
DrawTract   = p.Results.DrawTract;
DrawLight  	= p.Results.DrawLight;
GetDrawSet  = p.Results.GetDrawSet;
Remove      = p.Results.Remove;

% determine the version
%flg_version = all(version('-release') >= '2014a');

% deleted requested objects (based on handles)
if ishandle(Remove), Remove = {Remove}; end
for r = 1:numel(Remove)
  delete(Remove{r});
end

% specify hard-coded structural images
if ischar(FnameStruc) && strcmpi(FnameStruc,'mni');
  FnameStruc = fullfile(getenv('FSLDIR'),'data','standard','MNI152_T1_1mm_brain.nii.gz');
  if ~exist(FnameStruc,'file')
    error('MRCAT:TRACT3D:FnameStrucDoesNotExist','You specified to load a default MNI template, but it could not be located in the FSLDIR.');
  end
end

% get settings for DrawStruc, DrawTract, and DrawLight
if islogical(DrawStruc), DrawStruc = DrawStruc && ~isempty(FnameStruc); end
if islogical(DrawTract), DrawTract = DrawTract && ~isempty(FnameTract); end
S = get_DrawStruc(DrawStruc);
T = get_DrawTract(DrawTract);
L = get_DrawLight(DrawLight);

% return Draw settings if requested and return quickly
switch lower(GetDrawSet)
  case 'struc', hf = S; return;
  case 'tract', hf = T; return;
  case 'light', hf = L; return;
end

% initialize the figure
[hf,ha] = get_figure(hf);


%===============================
%% read in images
%===============================

% process structural image
if S.draw
  % expand fname and load structural images
  [S.img,S.dims,S.scale,S.hdr,S.fname] = read_avw_multi(FnameStruc);
  S.nr = S.dims(4);
  if S.nr > 1
    error('At the moment this script can only deal with a single structural image at a time.');
  end
end

% process tract image
if T.draw
  % expand fname and load tract images
  [T.img,T.dims,T.scale,T.hdr,T.fname] = read_avw_multi(FnameTract);
  T.nr = T.dims(4);

  % define tracts colors
  T = get_color(T,ha);

  % define thresholds
  T = get_threshold(T);

  % set FaceAlpha based on Threshold
  T = get_alpha(T);
end


%===============================
%% draw structural, tracts, and add lighting
%===============================

% draw structural
if S.draw
  S = draw_struc(S);
  lighting(L.lighting);
  material(L.material);
end


% draw thresholded tracts
if T.draw
  T.h.patch = draw_tract(T);
  lighting(L.lighting);
  material(L.material);
end


% add lightning
if L.draw
  L.h = draw_light(L);
end


%===============================
%% sub functions
%===============================

function S = get_DrawStruc(DrawStruc)
S.draw          = isstruct(DrawStruc) || DrawStruc;
S.flipLR        = false;
S.surf.vol      = 'hemiright';
% the limits used as input for W = subvolume(x,y,z,S.img,S.surf.vol)
%   1. coordinates: [nan nan 50 140 nan nan]
%   2. a string to evaluate: '[nan nan S.ymid S.ymax nan nan]'
%   3. a string: 'brain', 'none', 'hemileft', 'hemiright'
S.surf.thr      = 4700;
S.surf.reduce   = 0.3;              % 0 or an input to reducepatch
S.surf.color	= [0.5 0.5 0.5];
S.cut.vol       = S.surf(1).vol;
S.cut.thr       = S.surf(1).thr;
S.cut.alpha     = 1;
S.slice.cor.vol = [];               % scalar, or array for multiple
S.slice.cor.thr = S.surf(1).thr;
S.slice.cor.alpha = 0.8;
S.slice.sag.vol = [];               % leave empty to not draw
S.slice.sag.thr = S.surf(1).thr;
S.slice.sag.alpha = 0.8;
S.slice.ax.vol  = [];
S.slice.ax.thr  = S.surf(1).thr;
S.slice.ax.alpha = 0.8;
S.colormap      = 'gray';
S.CLim          = [1000 7500]; %'auto';

% try to return quickly
if islogical(DrawStruc), return; end

% combine defaults with current settings
S = combstruct(S,DrawStruc);
if isfield(DrawStruc,'surf') && ~isfield(DrawStruc,'cut')
  for s = 1:length(S.surf)
    S.cut(s).vol = S.surf(s).vol;
    S.cut(s).thr = S.surf(s).thr;
    S.cut(s).alpha = 1;
  end
end
if size(S.slice.cor.vol,2) > 1 && size(S.slice.cor.vol,2) ~= 6,
  S.slice.cor.vol = S.slice.cor.vol';
end
if size(S.slice.sag.vol,2) > 1 && size(S.slice.sag.vol,2) ~= 6,
  S.slice.sag.vol = S.slice.sag.vol';
end
if size(S.slice.ax.vol,2) > 1 && size(S.slice.ax.vol,2) ~= 6,
  S.slice.ax.vol = S.slice.ax.vol';
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function T = get_DrawTract(DrawTract)
T.draw          = isstruct(DrawTract) || DrawTract;
T.flipLR        = false;
T.thr           = [95 90];
T.thrtype       = 'auto';
T.alpha         = [];
T.color         = [];
T.smooth.mode  	= 'gaussian';   % 'gaussian', 'box', 'none'
T.smooth.kernel	= [3 3 3];

% try to return quickly
if islogical(DrawTract), return; end

% combine defaults with current settings
T = combstruct(T,DrawTract);
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function L = get_DrawLight(DrawLight)
L.draw          = isstruct(DrawLight) || DrawLight;
L.daspect       = [1 1 1];
L.axis          = 'tight';
L.view          = [-135 20];
L.camzoom       = 1.4;
L.camproj       = 'perspective';
L.light         = {};
L.lightangle    = {};
L.camlight      = {};
L.lighting      = 'gouraud';
L.material      = 'dull';       % 'default', 'shiny', 'metal', 'dull'

% try to return quickly
if islogical(DrawLight), return; end

% combine defaults with current settings
L = combstruct(L,DrawLight);

% ensure (cam)light options are in a cell array, properly
if ~iscell(L.camlight), L.camlight = {L.camlight}; end
if isempty(L.light)
  L.light = {};
else
  if ~iscell(L.light), L.light = {L.light}; end
  if ~iscell(L.light{1}), L.light = {L.light}; end
  if isempty(L.light{1}) || isempty(L.light{1}{1}), L.light = {}; end
end
if isempty(L.light) && isempty(L.lightangle) && isempty(L.camlight)
  L.camlight = {'right','left'};
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function [hf,ha] = get_figure(hf)
% check for figure or axes
flg_newfig = true;
if isempty(hf)
  % no figure or axes requested - generate new ones
  hf = figure; ha = gca(hf); cla(ha);
elseif ismember(hf,get(0,'children')')
  % existing figure - clear and set up
  ha = gca(hf); flg_newfig = false;
elseif isinteger(hf)
  % generating a new figure
  figure(hf); ha = gca(hf); cla(ha);
else
  % may be an axes - may be garbage
  try
    % is this an axes?
    if ismember(get(hf,'parent'),get(0,'children')')
      % existing figure axes - use
      ha = hf; hf = get(hf,'parent');
      flg_newfig = false;
    end
  catch
    % make new figure and axes
    fprintf('Invalid axes handle %g passed.  Generating new figure\n',hf)
    hf = figure; ha = gca(hf); cla(ha);
  end
end
% set the axes to the current axis and hold on
axes(ha); hold on;
% set to add plot
set(ha,'nextplot','add');
% set defaults for new figures
if flg_newfig
  if all(version('-release') >= '2014b')
    hf.Color = 'white';
    %hf.WindowStyle = 'docked';
    ha.Visible = 'off';
  else
    set(hf,'Color','white');
    set(ha,'Visible','off');
  end
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function T = get_color(T,ha)
% define tracts colors
if isempty(T.color) || ischar(T.color) && ismember(T.color,{'default','auto'})
  T.color = get(ha,'colororder');
  if T.nr > size(T.color,1)
    %T.color = [T.color; 1 0 0; 0 1 0; 0 0 1; 1 1 0; 1 0 1; 0 1 1];
    T.color = [T.color; 0 0 1; 1 1 0; 1 0 1; 0 1 1];
  end
  idx_col = rem(1:T.nr,size(T.color,1)); idx_col(idx_col==0) = size(T.color,1);
  T.color = T.color(idx_col,:);
elseif isnumeric(T.color) && (size(T.color,2) ~= 3 || numel(T.color) == T.nr)
  col = get(ha,'colororder');
  if T.nr > size(col,1)
    col = [col; 0 0 1; 1 1 0; 1 0 1; 0 1 1];
  end
  idx_col = rem(T.color,size(col,1)); idx_col(idx_col==0) = size(T.color,1);
  T.color = col(idx_col,:);
elseif ischar(T.color)
  if ismember(T.color,{'standard','regular','redyellowgreen'})
    T.color = [	0.9   0.2   0.1     % red
                0.9   0.85	0.25    % yellow
                0.3   0.75	0.2     % green
                0.6  	0.4  	0.1     % copper
                0     0.447	0.741   % blue
                0.301	0.745	0.933   % light blue
                0.494	0.184	0.556   % purple
                0.635	0.078	0.184 ];% ruby
  else
    T.color = T.color(:);
  end
end
if size(T.color,1) < T.nr
  error('The number of specified colours [%g] does not match the number of tracts [%g].',size(T.color,1),T.nr);
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function T = get_threshold(T)

% ensure there is a threshold set for each image (copy if necessary)
if size(T.thr,1) == 1
  T.thr = repmat(T.thr,T.nr,1);
end
if size(T.thr,1) ~= T.nr
  error('MrCat:tract3D:IncorrentNrThresholds','The number of Threshold rows [%g] does not match the number of tracts [%g].',size(T.thr,1),T.nr);
end

% set threshold based on percentiles for each image, if requested
if strcmpi(T.thrtype(1),'p') || (strcmpi(T.thrtype(1),'a') && all(T.thr(:)>=0 & T.thr(:)<100))
  % test for compliance to the range
  if ~(all(T.thr(:)>=0 & T.thr(:)<100))
    error('MrCat:tract3D:PercentileRangeExceeded','Percentile threshold must be between 0 and 100.');
  end
  % convert percentiles to a regular threshold
  for t = 1:T.nr
    val = T.img(:,:,:,t);
    T.thr(t,:) = prctile(val(val>0), T.thr(t,:));
  end
end

% sort
T.thr = sort(T.thr,2,'descend');
T.nr_thr = size(T.thr,2);
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function T = get_alpha(T)
% set FaceAlpha based on threshold
if isempty(T.alpha)
  switch T.nr_thr
    case 1
      T.alpha = 1;
    case 2
      T.alpha = [1 0.2];
    case 3
      T.alpha = [1 0.2 0.1];
    case 4
      T.alpha = [1 0.3 0.2 0.1];
    otherwise
      T.alpha = T.thr/max(T.thr);
  end
end
if length(T.alpha) ~= T.nr_thr
  error('The number of FaceAlpha values [%g] does not the number of Threshold values [%g]',length(alpha),T.nr_thr);
end
T.alpha = sort(T.alpha,'descend');
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function S = draw_struc(S)
% swap X and Y dimensions
S.img = permute(S.img,[2 1 3]);
% retrieve affine transformation matrix from header
afftrans = regexp(S.hdr{1},'(?<=sto_xyz:\d)\W+\d+\.\d+\W+\d+\.\d+\W+\d+\.\d+\W+\d+\.\d+','match');
afftrans = cell2mat(cellfun(@str2num,afftrans(:),'UniformOutput',false));
if isempty(afftrans) || any(isnan(afftrans(:)))
  afftrans = regexp(S.hdr{1},'(?<=qto_xyz:\d)\W+\d+\.\d+\W+\d+\.\d+\W+\d+\.\d+\W+\d+\.\d+','match');
  afftrans = cell2mat(cellfun(@str2num,afftrans(:),'UniformOutput',false));
end
% flip left-right
if S.flipLR
  warning('flipping left-right and applying affine transformation from header. This might be redundant.');
  S.img = fliplr(S.img);
end
% extract the [x y z] range of the volume
[m,n,p] = size(S.img);
xyz = [0    0   0   1
       n-1  m-1 p-1 1];
xyz = xyz * afftrans';
S.xmin = min(xyz(:,1)); S.xmax = max(xyz(:,1)); S.xmid = S.xmin+(S.xmax-S.xmin)/2;
S.ymin = min(xyz(:,2)); S.ymax = max(xyz(:,2)); S.ymid = S.ymin+(S.ymax-S.ymin)/2;
S.zmin = min(xyz(:,3)); S.zmax = max(xyz(:,3)); S.zmid = S.zmin+(S.zmax-S.zmin)/2;
S.x = linspace(xyz(1,1),xyz(2,1),n);
S.y = linspace(xyz(1,2),xyz(2,2),m);
S.z = linspace(xyz(1,3),xyz(2,3),p);
[S.x,S.y,S.z] = meshgrid(S.x,S.y,S.z);

% the old code below could create rounding errors. It's better to have
% meshgrid as the last step (as above)
% [S.x,S.y,S.z] = meshgrid(0:n-1,0:m-1,0:p-1);
% xyz = [S.x(:) S.y(:) S.z(:) ones(numel(S.x),1)];
% xyz = xyz * afftrans';
% S.x = reshape(xyz(:,1),m,n,p);
% S.y = reshape(xyz(:,2),m,n,p);
% S.z = reshape(xyz(:,3),m,n,p);
% S.xmin = min(S.x(:)); S.xmax = max(S.x(:)); S.xmid = S.xmin+(S.xmax-S.xmin)/2;
% S.ymin = min(S.y(:)); S.ymax = max(S.y(:)); S.ymid = S.ymin+(S.ymax-S.ymin)/2;
% S.zmin = min(S.z(:)); S.zmax = max(S.z(:)); S.zmid = S.zmin+(S.zmax-S.zmin)/2;

% draw sections
S.h.surf    = draw_struc_surf(S);
S.h.cut     = draw_struc_cut(S);
S.h.slice   = draw_struc_slice(S);

% set colormap and range
colormap(S.colormap);
caxis(S.CLim);
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function hsurf = draw_struc_surf(S)
% loop over surfaces
for s = 1:length(S.surf)
  if isempty(S.surf(s).vol) || isequal(S.surf(s).vol,'none'), hsurf(s) = 0; return; end

  % set the limits of the volume
  if ischar(S.surf(s).vol)
    switch lower(S.surf(s).vol)
      case 'brain',       lim = [S.xmin,S.xmax,nan,nan,nan,nan];
      case 'hemileft',    lim = [S.xmid,S.xmax,nan,nan,nan,nan];
      case 'hemiright',   lim = [S.xmin,S.xmid,nan,nan,nan,nan];
      otherwise,          lim = eval(S.surf(s).vol);
    end
  else
    lim = S.surf(s).vol;
  end

  % extract the volume
  [xV,yV,zV,V] = subvolume(S.x,S.y,S.z,S.img,lim);
  % draw the surface
  hsurf(s) = patch(isosurface(xV,yV,zV,V,S.surf(s).thr));
  if S.surf(s).reduce > 0, reducepatch(hsurf(s),S.surf(s).reduce); end
  %hsurf(s).FaceColor = S.surf(s).color;
  %hsurf(s).EdgeColor = 'none';
  set(hsurf(s),'FaceColor',S.surf(s).color);
  set(hsurf(s),'EdgeColor','none');
  isonormals(xV,yV,zV,V,hsurf(s));

end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function hcut = draw_struc_cut(S)
% loop over cuts
for c = 1:length(S.cut)
  if isempty(S.cut(c).vol) || isequal(S.cut(c).vol,'none'), hcut(c) = 0; return; end

  % set the limits of the volume
  if ischar(S.cut(c).vol)
    switch lower(S.cut(c).vol)
      case 'brain',       lim = [S.xmin,S.xmax,nan,nan,nan,nan];
      case 'hemileft',    lim = [S.xmid,S.xmax,nan,nan,nan,nan];
      case 'hemiright',   lim = [S.xmin,S.xmid,nan,nan,nan,nan];
      otherwise,          lim = eval(S.cut(c).vol);
    end
  else
    lim = S.cut(c).vol;
  end

  % extract the volume
  [xV,yV,zV,V] = subvolume(S.x,S.y,S.z,S.img,lim);
  % draw the cutting plane (sagittal)
  hcut(c) = patch(isocaps(xV,yV,zV,V,S.cut(c).thr));
  %hcut(c).FaceColor = 'interp';
  %hcut(c).EdgeColor = 'none';
  %hcut(c).FaceAlpha = S.cut(c).alpha;
  set(hcut(c),'FaceColor','interp');
  set(hcut(c),'EdgeColor','none');
  set(hcut(c),'FaceAlpha',S.cut(c).alpha);
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function h = draw_struc_slice(S)
h = [];
% draw slices if requested
if ~isempty(S.slice.cor.vol) && ~isequal(S.slice.cor.vol,'none')
  % extract and draw coronal slice(s)
  h.cor = cell(1,size(S.slice.cor.vol,1));
  for v = 1:size(S.slice.cor.vol,1)
    lim = S.slice.cor.vol(v,:);
    if size(lim,2)==1, lim = [nan,nan,lim,nan,nan,nan]; end
    [xV,yV,zV,V] = subvolume(S.x,S.y,S.z,S.img,lim);
    h.cor{v} = patch(isocaps(xV,yV,zV,V,S.slice.cor.thr));
    %h.cor{v}.FaceColor = 'interp';
    %h.cor{v}.EdgeColor = 'none';
    %h.cor{v}.FaceAlpha = S.slice.cor.alpha;
    set(h.cor{v},'FaceColor','interp');
    set(h.cor{v},'EdgeColor','none');
    set(h.cor{v},'FaceAlpha',S.slice.cor.alpha);
  end
end
if ~isempty(S.slice.sag.vol) && ~isequal(S.slice.sag.vol,'none')
  % extract and draw sagittal slice(s)
  h.sag = cell(1,size(S.slice.sag.vol,1));
  for v = 1:size(S.slice.sag.vol,1)
    lim = S.slice.sag.vol(v,:);
    if size(lim,2)==1, lim = [lim,nan,nan,nan,nan,nan]; end
    [xV,yV,zV,V] = subvolume(S.x,S.y,S.z,S.img,lim);
    h.sag{v} = patch(isocaps(xV,yV,zV,V,S.slice.sag.thr));
    %h.sag{v}.FaceColor = 'interp';
    %h.sag{v}.EdgeColor = 'none';
    %h.sag{v}.FaceAlpha = S.slice.sag.alpha;
    set(h.sag{v},'FaceColor','interp');
    set(h.sag{v},'EdgeColor','none');
    set(h.sag{v},'FaceAlpha',S.slice.sag.alpha);
  end
end
if ~isempty(S.slice.ax.vol) && ~isequal(S.slice.ax.vol,'none')
  % extract and draw axial slice(s)
  h.ax = cell(1,size(S.slice.ax.vol,1));
  for v = 1:size(S.slice.ax.vol,1)
    lim = S.slice.ax.vol(v,:);
    if size(lim,2)==1, lim = [nan,nan,nan,nan,lim,nan]; end
    [xV,yV,zV,V] = subvolume(S.x,S.y,S.z,S.img,lim);
    h.ax{v} = patch(isocaps(xV,yV,zV,V,S.slice.ax.thr));
    %h.ax{v}.FaceColor = 'interp';
    %h.ax{v}.EdgeColor = 'none';
    %h.ax{v}.FaceAlpha = S.slice.ax.alpha;
    set(h.ax{v},'FaceColor','interp');
    set(h.ax{v},'EdgeColor','none');
    set(h.ax{v},'FaceAlpha',S.slice.ax.alpha);
  end
end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function h = draw_tract(T)
% draw tracts

% loop over tracts
h = cell(T.nr,T.nr_thr);
for t = 1:T.nr

  % extract the data
  img = T.img(:,:,:,t);
  % swap X and Y dimensions
  img = permute(img,[2 1 3]);
  % retrieve affine transformation matrix from header
  afftrans = regexp(T.hdr{t},'(?<=sto_xyz:\d)\W+\d+\.\d+\W+\d+\.\d+\W+\d+\.\d+\W+\d+\.\d+','match');
  afftrans = cell2mat(cellfun(@str2num,afftrans(:),'UniformOutput',false));
  if isempty(afftrans) || any(isnan(afftrans(:)))
    afftrans = regexp(T.hdr{t},'(?<=qto_xyz:\d)\W+\d+\.\d+\W+\d+\.\d+\W+\d+\.\d+\W+\d+\.\d+','match');
    afftrans = cell2mat(cellfun(@str2num,afftrans(:),'UniformOutput',false));
  end
  % flip left-right
  if T.flipLR
    warning('flipping left-right and applying affine transformation from header. This might be redundant.');
    img = fliplr(img);
  end
  % smooth the data
  if ~strcmpi(T.smooth.mode,'none')
    img = smooth3(img,T.smooth.mode,T.smooth.kernel);
  end

  % get [x y z] positions
  [m,n,p] = size(img);
  [x,y,z] = meshgrid(0:n-1,0:m-1,0:p-1);
  xyz = [x(:) y(:) z(:) ones(numel(x),1)];
  xyz = xyz * afftrans';
  x = reshape(xyz(:,1),m,n,p);
  y = reshape(xyz(:,2),m,n,p);
  z = reshape(xyz(:,3),m,n,p);

  % loop over thresholds and plot progressively
  for p = 1:T.nr_thr
    h{t,p} = patch(isosurface(x,y,z,img,T.thr(t,p)));
    %reducepatch(h{t,p},0.5);
    isonormals(x,y,z,img,h{t,p});
    %h{t,p}.FaceColor = T.color(t,:);
    %h{t,p}.EdgeColor = 'none';
    %h{t,p}.FaceAlpha = T.alpha(p);
    set(h{t,p},'FaceColor',T.color(t,:));
    set(h{t,p},'EdgeColor','none');
    set(h{t,p},'FaceAlpha',T.alpha(p));
    hold on;
  end

end
%--------------------------------------------------------------------------

%--------------------------------------------------------------------------
function h = draw_light(L)
% set view and lighting
daspect(L.daspect);
axis(L.axis);
view(L.view);
camzoom(L.camzoom)
camproj(L.camproj)
h.light = cell(size(L.light));
for l = 1:length(L.light)
  h.light{l} = light(L.light{l}{:});
end
h.lightangle = cell(size(L.lightangle));
for a = 1:length(L.lightangle)
  la = L.lightangle{a};
  if ischar(la), h.lightangle{a} = lightangle(la);
  elseif iscell(la), h.lightangle{a} = lightangle(la{:});
  elseif all(isnumeric(la)) && numel(la)==2, h.lightangle{a} = lightangle(la(1),la(2));
  else h.lightangle{a} = lightangle(la); % will probably return an error
  end
end
h.camlight = cell(size(L.camlight));
for c = 1:length(L.camlight)
  cl = L.camlight{c};
  if ischar(cl), h.camlight{c} = camlight(cl);
  elseif iscell(cl), h.camlight{c} = camlight(cl{:});
  elseif all(isnumeric(cl)) && numel(cl)==2, h.camlight{c} = camlight(cl(1),cl(2));
  else h.camlight{c} = camlight(cl); % will probably return an error
  end
end
lighting(L.lighting);
material(L.material);
