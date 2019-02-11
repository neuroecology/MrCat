function mat2dtseries(data,outputbase,hemi)
% function mat2dtseries(data,outputbase,hemi)
%
% Create dtseries CIFTI file based on a matrix using an inelegant route via
% .func.gii files
%-------------------------------------------------------------------------
%
% Obligatory inputs:
%   data        vertices*time data matrix
%   outputbase  String containing output base
%   hemi        Hemisphere/structure used ('R', 'L', or 'LR')
%
% version history
% 28042028 Rogier   Use saveimgfile instead of create_func_gii
% 16022018 Rogier   Added 'LR' option
% 16012018 Rogier   Created
%
% copywright
% Rogier B. Mars, Univeristy of Oxford/Donders Institute, 2018
%-------------------------------------------------------------------------

% Get wb_command
wb_command = getenv('wb_command');

% Create temp .func.gii files and merge
switch hemi
    case 'L'
        cmd = [wb_command ' -metric-merge ' [outputbase '_L_temp_all.func.gii']];
        for i = 1:size(data,2)
            saveimgfile(data(:,i),[outputbase '_L_temp' num2str(i) '.func.gii'],hemi);
            cmd = [cmd ' -metric ' [outputbase '_L_temp' num2str(i)] '.func.gii'];
        end
        unix(cmd);
    case 'R'
        cmd = [wb_command ' -metric-merge ' [outputbase '_R_temp_all.func.gii']];
        for i = 1:size(data,2)
            saveimgfile(data(:,i),[outputbase '_R_temp' num2str(i) '.func.gii'],hemi);
            cmd = [cmd ' -metric ' [outputbase '_R_temp' num2str(i)] '.func.gii'];
        end       
        unix(cmd);
    case 'LR'
        dataL = data(1:size(data,1)/2,:);
        cmd = [wb_command ' -metric-merge ' [outputbase '_L_temp_all.func.gii']];
        for i = 1:size(dataL,2)
            saveimgfile(dataL(:,i),[outputbase '_L_temp' num2str(i) '.func.gii'],'L');
            cmd = [cmd ' -metric ' [outputbase '_L_temp' num2str(i)] '.func.gii'];
        end
        unix(cmd);
        dataR = data((size(data,1)/2)+1:end,:);
        cmd = [wb_command ' -metric-merge ' [outputbase '_R_temp_all.func.gii']];
        for i = 1:size(dataR,2)
            saveimgfile(dataR(:,i),[outputbase '_R_temp' num2str(i) '.func.gii'],'R');
            cmd = [cmd ' -metric ' [outputbase '_R_temp' num2str(i)] '.func.gii'];
        end
        unix(cmd);
end

% Convert merged .func.gii to .dtseries.nii
switch hemi
    case 'L'
        cmd = [wb_command ' -cifti-create-dense-timeseries ' [outputbase '.dtseries.nii'] ' -left-metric ' [outputbase '_L_temp_all.func.gii']];
    case 'R'
        cmd = [wb_command ' -cifti-create-dense-timeseries ' [outputbase '.dtseries.nii'] ' -right-metric ' [outputbase '_R_temp_all.func.gii']];
    case 'LR'
        cmd = [wb_command ' -cifti-create-dense-timeseries ' [outputbase '.dtseries.nii'] ' -left-metric ' [outputbase '_L_temp_all.func.gii'] ' -right-metric ' [outputbase '_R_temp_all.func.gii']];
end
unix(cmd);

% Clean up
warning('off','all');
delete([outputbase '_R_temp_all.func.gii']);
delete([outputbase '_L_temp*.func.gii']);
delete([outputbase '_R_temp*.func.gii']);
warning('on','all');
