function saveimgfile(data,filename,reqparam,varargin)
% function saveimgfile(data,filename,reqparam)
%
% This is the compantion of readimgfile, allowing you to save as many image
% format files as possible, based on a matrix. Various external toolboxes
% are required. Currently, the following are supported and need reqparam:
%   .nii.gz         [x y z TR] or [x y z], voxel size
%   .func.gii       'R' or 'L', string containing hemisphere
%   .dtseries.nii   'R', 'L', or 'LR', string containing hemisphere
%   .mat
%   .txt
%   
%--------------------------------------------------------------------------
%
% Use:
%   saveimgfile(data,'myfile.nii.gz',[1 1 1]);
%   saveimgfile(data,'myfile.func.gii','R');
%
% Obligatory inputs:
%   data        data matrix
%   filename    string containing filename with extension
%   reqparam    required parameter (see above)
%
% Optional inputs (using parameter format):
%   fslcpgeom   image to copy geometry using fslcpgeom
%
% Uses: save_nii.m, gzip.m, strcontain.m, strerase.m, create_func_gii.m
%
% version history
% 2021-04-14    Rogier  added fslcpgeom varargin option
% 2020-07-21    Rogier  added .txt output option
% 2018-08-15    Rogier  can now handle .surf.gii using Martin's
%                       create_gifti
% 2018-07-10    Rogier  .nii.gz now forces radiological (note: doesn't flip
%                       data, just add info to the header)
% 2018-04-20    Rogier  Changed .func.gii to use Martin's create_gifti
% 2018-03-09    Rogier  SWAT! Added removal of .nii after gzip to .nii.gz
% 2018-02-15	Rogier  created
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2016-02-15
%--------------------------------------------------------------------------

%==================================================
% Optional inputs
%==================================================

fslcpgeom = [];

if nargin>3
    for vargnr = 2:2:length(varargin)
        switch varargin{vargnr-1}
            case 'fslcpgeom'
                fslcpgeom = varargin{vargnr};
        end
    end
end

%==================================================
% Determine file type
%==================================================

if strcontain(filename,'.nii.gz')
    filetype = '.nii.gz';
elseif strcontain(filename,'.func.gii')
    filetype = '.func.gii';
elseif strcontain(filename,'.dtseries.nii')
    filetype = '.dtseries.nii';
elseif strcontain(filename,'.mat')
    filetype = '.mat';
elseif strcontain(filename,'surf.gii')
    filetype = '.surf.gii';
elseif strcontain(filename,'txt')
    filetype = '.txt';
else
    error('Error in MrCat:saveimgfile: File type not found!');
end

%==================================================
% Save data
%==================================================

switch filetype
    case '.nii.gz'
        nii = make_nii(data,reqparam);
        save_nii(nii,strerase(filename,'.gz'));
        gzip(strerase(filename,'.gz'));
        delete(strerase(filename,'.gz'));
        FSLDIR = getenv('FSLDIR');
        unix([FSLDIR '/bin/fslorient -forceradiological ' filename]);
        if ~isempty(fslcpgeom)
            unix([FSLDIR '/bin/fslcpgeom ' fslcpgeom ' ' filename ' -d']);
        end
    case '.func.gii'
        if isequal(reqparam,'R') || isequal(reqparam,'L')
                % create_func_gii(data,strerase(filename,filetype),reqparam);
                create_gifti('func',filename,data,reqparam);
        else
            error('Error in MrCat:saveimgfile: unknown hemisphere for .func.gii!');
        end
    case '.dtseries.nii'
        if isequal(reqparam,'R') || isequal(reqparam,'L') || isequal(reqparam,'LR')
                mat2dtseries(data,strerase(filename,filetype),reqparam);
        else
            error('Error in MrCat:saveimgfile: unknown hemisphere for .dtseries.nii!');
        end
    case '.mat'
        save(filename,'data','-v7.3');
    case '.surf.gii'
        if isequal(reqparam,'R') || isequal(reqparam,'L')
            create_gifti('surf',filename,data,reqparam);
        else
            error('Error in MrCat:saveimgfile: unknown hemisphere for .surf.gii!');
        end
    case '.txt'
        save(filename,'data','-ascii');
end