function [data, varargout] = readimgfile(filename,varargin)
% function [data, varargout] = readimgfile(filename,varargin)
%
% Read in any file that is vaguely related to neuroimaging, with or without
% specifying extension. If a .nii is found without .dconn or
% .dtseries it will assume that it is dealing with a NIFTI file. If no
% extension is specified it will try to find files in the order: .dot,
% .func.gii, .surf.gii, nii.gz, .dconn.nii, .dtseries.nii, dscalar.nii,
% dlabel.nii, .nii, and .mat.
%--------------------------------------------------------------------------
%
% Use:
%   data = readimgfile('myfile.dconn.nii');
%   [data, filetype] = readimgfile('yourfile');
%   [data, filetype, hdr] = readimgfile('yourfile');
%
% Obligatory input:
%   filename    string containing filename (with or without extension)
%
% Optional input (using parameter format):
%   dealwithnan     'no' (default), 'yes' to replace with zero, or value to
%                   replace nan with
%   dealwithinf     'no' (default), 'yes' to replace with zero and add 1 to
%                   all other values, or value to replace -Inf with
%
% Outputs:
%   data            matrix with data
%   varargout{1}    string containing file type
%   varargout{2}    header
%
% Uses: read_avw.m, ciftiopen.m, gifti toolbox, load_nifti.m, see their
% separate docs. Compatible with MrCat versions
%
% version history
% 2018-09-18    Suhas   Try ciftiopen when cifti_open fails to load dconn
% 2018-08-29    Rogier  Improved error handling
% 2018_06-12    Rogier  Changed to use new cifti_open.m for CIFTI files
% 2018-06-06    Rogier  Improved wb_command handling
% 2017-09-14    Rogier  Swatted small bug in .mat functionality
% 2017-09-13    Rogier  Added .mat functionality to increase compatibility
% 2017-09-05    Rogier  Added dlabel.nii functionality
% 2017-05-30 Davide/Rogier Added option to deal with dscalar cifti
% 2017-02-15    Rogier  Added file not found warning
% 2016-07-13    Rogier  Changed nifti handling to use Freesurfer's
%                       load_nifti.m and added varargout{2} for the header
% 2016-05-27    Rogier  Added varargout file type
% 2016-04-22    Rogier  Fixed bug dealing with .surf.gii instead of
%                       .func.gii
% 2016-04-20    Rogier  Added options to deal with nan and -inf
% 2016-04-20	Rogier  created
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2016-04-20
%--------------------------------------------------------------------------

%==================================================
% Housekeeping
%==================================================

% Defaults
dealwithnan = 'no';
dealwithinf = 'no';
hdr = [];

if nargin>1
    for vargnr = 2:2:length(varargin)
        switch varargin{vargnr-1}
            case 'dealwithnan'
                dealwithnan = varargin{vargnr};
            case 'dealwithinf'
                dealwithinf = varargin{vargnr};
        end
    end
end

% Check if file exists
if ~exist(filename,'file'), error(['Error in MrCat:readimgfile: File ' filename ' not found!']); end

%==================================================
% Determine file type
%==================================================

[d,f,e] = fileparts(filename);

if ~isempty(e)
    
    if isequal(e,'.dot') % .dot file
        filetype = 'DOT';
    elseif isequal(e,'.gii') % gifti file
        filetype = 'GIFTI';
    elseif isequal(e,'.gz') % .nii.gz file
        filetype = 'NIFTI_GZ';
    elseif isequal(e,'.nii') % nifti or cifti file
        if regexp(f,'dconn') % dconn.nii file
            filetype = 'DCONN';
        elseif regexp(f,'dtseries') % dtseries.nii
            filetype = 'DTSERIES';
        elseif regexp(f,'dscalar') % dscalar.nii
            filetype = 'DSCALAR';
        elseif regexp(f,'dlabel') % dlabel.nii
            filetype = 'DLABEL';
        else % assuming nifti
            filetype = 'NIFTI';
        end
    elseif isequal(e,'.mat') % .mat file
            filetype = 'MAT';
    end
    
elseif isempty(e)
    
    if exist([filename '.dot'],'file')
        filetype = 'DOT';
        filename = [filename 'dot'];
    elseif exist([filename '.func.gii'],'file')
        filetype = 'GIFTI';
        filename = [filename 'func.gii'];
    elseif exist([filename '.surf.gii'],'file')
        filetype = 'GIFTI';
        filename = [filename 'surf.gii'];
    elseif exist([filename '.nii.gz'],'file')
        filetype = 'NIFTI_GZ';
        filename = [filename '.nii.gz'];
    elseif exist([filename '.dconn.nii'],'file')
        filetype = 'DCONN';
        filename = [filename '.dconn.nii'];
    elseif exist([filename '.dtseries.nii'],'file')
        filetype = 'DTSERIES';
        filename = [filename '.dtseries.nii'];
    elseif exist ([filename '.dscalar.nii'], 'file');
        filetype = 'DSCALAR';
        filename = [filename '.dscalar.nii'];
    elseif exist ([filename '.dlabel.nii'], 'file');
        filetype = 'DLABEL';
        filename = [filename '.dlabel.nii'];
    elseif exist([filename '.nii'],'file')
        filetype = 'NIFTI';
        filename = [filename '.nii'];
    elseif exist([filename '.mat'],'file');
        filetype = 'MAT';
        filename = [filename '.mat'];
    else
        error('Error in MrCat:readimgfile: File type not found!');
    end
    
end

%==================================================
% Load data
%==================================================

switch filetype
    
    case 'DOT'
        data = load(filename);
        data=full(spconvert(data)); % Reorder the data
    case 'GIFTI'        
        try
            data = load_gifti_data(filename);
        catch
            data = gifti(filename);
            data = data.cdata;
        end                
    case 'NIFTI_GZ'
        % data = read_avw(filename);
        hdr = load_nifti(filename);
        data = hdr.vol;
    case 'DCONN'
        % Get wb_command
        wb_command = getenv('wb_command');
        try
            data = cifti_open(filename,wb_command);
        catch
            data = ciftiopen(filename);
        end
        data = data.cdata;
    case 'DTSERIES'
        wb_command = getenv('wb_command');
        data = cifti_open(filename,wb_command);
        data = data.cdata;
    case 'DSCALAR'
        wb_command = getenv('wb_command');
        data = ciftiopen(filename,wb_command);
        data = data.cdata;
    case 'DLABEL'
        wb_command = getenv('wb_command');
        data = ciftiopen(filename,wb_command);
        data = data.cdata;
    case 'NIFTI'
        data = read_avw(filename);
    case 'MAT'
        data = load(filename);
end

%==================================================
% Manipulate data if so requested
%==================================================

switch dealwithnan
    case 'no'
        % do nothing
    case 'yes'
        data = replacenan(data,0);
    otherwise
        data = replacenan(data,dealwithnan);
end

switch dealwithinf
    case 'no'
        % do nothing
    case 'yes'
        data = data+1;
        data(find(data(:)==-Inf)) = 0;
    otherwise
        data(find(data(:)==-Inf)) = dealwithinf;
end

%==================================================
% Prepare variable output
%==================================================

varargout{1} = filetype;
varargout{2} = hdr;