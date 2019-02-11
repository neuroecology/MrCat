function [img,dims,scales,hdr,fname] = read_avw_multi(fname,dims_ref)
%--------------------------------------------------------------------------
% a wrapper around read_avw from fsl that supports filter input and
% can concatenate multiple images into a 4D matrix
%
% Input
%   fname       name of the nifti/or analyse image. Filters are accepted,
%               for example '*.nii.gz'. Pass mutliple fnames in a cell
%               array.
%   dims_ref	a 1x3 or 1x4 array of reference dimensions to match
%
% Output
%   img         a 4D matrix of the image data
%   dims        a 1x4 array of dimensions of the img matrix
%   scales      a 4xn array of scaling ratios from vox to mm
%   hdr         a cell array with the output of 'fslhd' on the files
%   fname       a cell array of successfully read in files
%
% version history
% 2015-09-14    Lennart added full header report using 'fslhd'
% 2015-02-23    Lennart implemented subdir and rdir options to expandfname
% 2015-02-17    Lennart created
%
% Lennart Verhagen & Rogier B. Mars
% University of Oxford, 2015-02-01
%--------------------------------------------------------------------------
narginchk(1,2);
if nargin < 2, dims_ref = []; end

% check if read_avw is included
if isempty(which('read_avw'))
  if isempty(getenv('FSLDIR')), error('MRCAT:READ_AVW_MULTI:NoFSLDIR','The required function ''read_avw'' was not found on the path, nor was the FSL directory specified'); end
  addpath(fullfile(getenv('FSLDIR'),'etc','matlab'));
end

%% read in images
%-------------------------------
% expand and check image file name
fname_exp = expandfname(fname); %,'subdir');
if isempty(fname_exp), if iscell(fname), fname = fname{1}; end; error('MRCAT:InvalidFilename','image file ''%s'' could not be found.',fname); end
fname = fname_exp;

% initialise img matrix based on dims_match
if ~isempty(dims_ref)
  dims_ref = dims_ref(:);
  dims_all = [dims_ref(1:3); 0];
  img_all = nan(dims_all');
  scales_all = nan(4,0);
end

% loop over probtrack files to load
fname_all = {};
hdr_all = {};
for f = 1:length(fname)
  
  % read in current image
  [img, dims, scales] = read_avw(safefname(fname{f}));
  
  % read in full header using fslhd
  command = sprintf('FSLOUTPUTTYPE=NIFTI_GZ; export FSLOUTPUTTYPE; $FSLDIR/bin/fslhd %s', safefname(fname{f}));
  [status,hdr]=call_fsl(command);
  if (status), error(hdr); end
  hdr_all{end+1:end+dims(4)} = hdr;
  
  % store fname and image or give an error
  fname_all{end+1:end+dims(4)} = fname{f};
  if isempty(dims_ref) && f == 1
    % store first image as reference
    img_all = img;
    dims_all = dims;
    scales_all = scales;
  elseif isequal(dims_all(1:3),dims(1:3))
    % concatenate
    img_all(:,:,:,end+1:end+dims(4)) = img;
    scales_all(:,end+1:end+1) = scales;
  elseif isempty(dims_ref)
    error('MRCAT:InvalidDims','The dimensions of the image ''%s'' [%s] do not match those of the first image ''%s'' [%s].',fname{f},num2str(dims(1:3)'),fname_all{1},num2str(dims_all(1:3)'));
  else
    error('MRCAT:InvalidDims','The dimensions of the image ''%s'' [%s] do not match the reference dimensions [%s].',fname{f},num2str(dims(1:3)'),num2str(dims_ref(1:3)'));
  end
  
end
% update dimensions, even if singular
dims_all(4) = size(img_all,4);


%% output
%-------------------------------
img = img_all;
dims = dims_all;
scales = scales_all;
hdr = hdr_all;
fname = fname_all;


%% sub functions (can be found in Lennart's public folder)
%-------------------------------

% function fname_expanded = expandfname(fname,fun,varargin)
% %--------------------------------------------------------------------------
% % expand the file name to accomodate folder and filter entries
% %
% % fname - file (can contain wildcard) name to expand
% % fun   - directory listing function: 'dir' [default], 'rdir', 'subdir'
% %
% % Lennart Verhagen
% % University of Oxford, 2015-02-01
% %--------------------------------------------------------------------------
% if nargin < 2, fun = 'dir'; end
%
% % convert image file name to cell and loop
% if ~iscell(fname), fname = {fname}; end
% fname_expanded = {};
% for f = 1:length(fname)
%     if ~exist(fname{f},'dir')
%         % enforce .nii.gz extension for files
%         idx = regexp(fname{f},'\.\w','start','once');
%         if isempty(idx), fname{f} = [fname{f} '.nii.gz']; end
%     end
%     % list files matching filter
%     switch fun
%         case 'dir'
%             fname_tmp = dir(fname{f});
%         case 'subdir'
%             fname_tmp = subdir(fname{f});
%         case 'rdir'
%             fname_tmp = rdir(fname{f},varargin{:});
%     end
%     % exclude directories
%     fname_tmp = fname_tmp(~[fname_tmp.isdir]);
%     fname_tmp = {fname_tmp.name};
%     % prepad with path if 'dir' is used to list the files
%     if strcmpi(fun,'dir')
%         fname_tmp = cellfun(@(x) fullfile(fileparts(fname{f}),x),fname_tmp,'UniformOutput',false);
%     end
%     % append to output cell
%     fname_expanded(end+1:end+length(fname_tmp)) = fname_tmp;
% end
%
%
% function fname_safe = safefname(fname)
% %--------------------------------------------------------------------------
% % ignore spaces in the filename by prepadding them with a backslash
% %
% % Lennart Verhagen
% % University of Oxford, 2015-02-01
% %--------------------------------------------------------------------------
% fname_safe = regexprep(fname,'(?<!\\) ','\\ ');
