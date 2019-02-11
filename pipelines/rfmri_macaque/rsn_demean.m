function rsn_demean(fname,padname)
% function rsn_demean(inputfile,padname)
%
% Demean the time course of 4D .nii.gz or 2D .dtseries.nii file for
% rfmri_macaque. The output file will be named by padding the input
% filename with the padname. When padname is empty, the output will replace the
% input file.
%--------------------------------------------------------------------------
%
% Use:
%   rsn_demean('myfile.dtseries.nii');
%
% Obligatory input:
%   filename    string containing filename (with extension)
%
% Uses: read_avw.m, save_avw.m, ciftiopen.m, ciftisave.m, readimgfile.m,
% see their separate docs.
% Compatible with MrCat versions
%
% version history
% 2016-06-15	Lennart  created based on rsn_normalise_ts.m by Rogier Mars
%
% copyright
% Lennart Verhagen & Rogier B. Mars
% University of Oxford & Donders Institute, 2016-06-15
%--------------------------------------------------------------------------

% Determine data type
fprintf('Determining file type...\n');
[~,datatype] = readimgfile(fname);

% add a padding to the name of the output file
fname_out = regexp(fname,'\.','split','once');
fname_out = [fname_out{1} padname '.' fname_out{2}];

switch datatype

    case 'NIFTI_GZ'
        fprintf('Demeaning NIFTI time series along 4th dimension...\n');

        [data, dims,scales,bpp,endian] = read_avw(fname);
        data = bsxfun(@minus,data,mean(data,4));
        save_avw(data,fname_out,'f',scales');

    case 'DTSERIES'
        fprintf('Demeaning dtseries along 2nd dimension...\n');

        cifti = ciftiopen(fname);
        cifti.cdata = bsxfun(@minus,cifti.cdata,mean(cifti.cdata,2));
        ciftisave(cifti,fname_out,size(cifti.cdata,1),'wb_command');

    otherwise
        error('Error in rsn_normalise_ts: Input data type not supported!');

end

disp('done');
