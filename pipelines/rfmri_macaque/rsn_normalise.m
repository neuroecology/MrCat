function rsn_normalise(fname,padname,wb_command)
% function rsn_normalise(inputfile,padname,wb_command)
%
% Normalise the time course of 4D .nii.gz or 2D .dtseries.nii file for
% rfmri_macaque. The output file will be named by padding the input
% filename with the padname. When padname is empty, the output will replace
% the input file. When saving *.dtseries.nii files, 'wb_command' specifies
% the path to the wb_command binary to save the output file (when left
% empty, it will infer the name from the .bash_profile).
%--------------------------------------------------------------------------
%
% Use:
%   rsn_normalise('myfile.dtseries.nii');
%
% Obligatory input:
%   filename    string containing filename (with extension)
%
% Uses: read_avw.m, save_avw.m, ciftiopen.m, ciftisave.m, readimgfile.m,
% see their separate docs.
% Compatible with MrCat versions
%
% version history
% 2017-11-06  Lennart polished
% 2016-06-15	Rogier  created
%
% copyright
% Rogier B. Mars
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
        fprintf('Normalising NIFTI time series along 4th dimension...\n');

        [data, dims, scales, bpp, endian] = read_avw(fname);
        data = normalise(data,4);
        save_avw(data,fname_out,'f',scales');

    case 'DTSERIES'
        fprintf('Normalising dtseries along 2nd dimension...\n');
        if nargin<3 || isempty(wb_command)
          % infer the location of wb_command from the .bash_profile
          [~,wb_command] = unix('cat ~/.bash_profile | grep "/workbench/" | head -1 | cut -d"=" -f2 | tr "\n" "/"');
          wb_command = fullfile(wb_command,'wb_command');
        end

        cifti = ciftiopen(fname);
        cifti.cdata = normalise(cifti.cdata,2);
        ciftisave(cifti, fname_out, size(cifti.cdata,1), wb_command);

    otherwise
        error('Error in rsn_normalise: Input data type not supported!');

end

disp('done');
