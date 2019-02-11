function [gifti_data] = load_gifti_data(ip_file)

% For those cases when you just want the data without all the rest of the
% metadata etc.

% Inputs:
%   ip_file: The filename including path of the gifti 

%  Outputs:
%     gifti_data: The structure of this depends on  the type of input file.
%     For surface files it is a structure containing gifti_data.vertices
%     and gifti_data.faces. 
%     For label files it is a structure with the data arrays and the label table  
%     For all other types it is a simple 2D array.

% Martin Guthrie 2017

% Version history
% Guilherme Freches   v1.1      Added possibility of reading 4-d func.gii
% Martin Guthrie    13022018    Added 'label' functionality
% Martin Guthrie      v1.0      2018-02-05

%%
if ~exist(ip_file, 'file')
    error('Input file %s does not exist', ip_file);
end

file_type = get_gifti_type(ip_file);
gifti_struct = load_gifti(ip_file);
if strcmpi(file_type, 'surf')
    % Only surface files have both vertices and faces
    if strcmpi(gifti_struct.NumberOfDataArrays, '2')
        for i_array = 1:2
            switch upper(gifti_struct.DataArray{i_array}.Intent)
                case 'NIFTI_INTENT_POINTSET'
                    % vertices are a floating point array with Intent="NIFTI_INTENT_POINTSET"
                    gifti_data.vertices = gifti_struct.DataArray{i_array}.Data;
                case 'NIFTI_INTENT_TRIANGLE'
                    % faces are an integer array with Intent="NIFTI_INTENT_TRIANGLE"
                    gifti_data.faces = gifti_struct.DataArray{i_array}.Data;
            end
        end
    else
        warning('Surface file %s only contain(s) %d data arrays', ...
                    ip_file, gifti_struct.NumberOfDataArrays);
    end
elseif strcmpi(file_type, 'label')
    % We have a label file
    gifti_data.data = gifti_struct.DataArray;
    gifti_data.label.name = {gifti_struct.LabelTable.Name};
    gifti_data.label.key = str2double({gifti_struct.LabelTable.Key});
    rgba = str2double({gifti_struct.LabelTable.Red, ...
                        gifti_struct.LabelTable.Green, ...  
                        gifti_struct.LabelTable.Blue, ...
                        gifti_struct.LabelTable.Alpha});
    gifti_data.label.rgba = reshape(rgba, [length(rgba) / 4, 4]);
else
    % It is a func or a shape, so only one data array
    gifti_data = zeros(length(gifti_struct.DataArray{1}.Data),length(gifti_struct.DataArray));
    i=1;
    while i<=length(gifti_struct.DataArray)
    gifti_data(:,i) = gifti_struct.DataArray{i}.Data;
    i=i+1;
    end
end

end