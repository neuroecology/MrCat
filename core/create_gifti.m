function op_file = create_gifti(gifti_type, filename, data, hemisphere, additional_metadata)
% function op_file = create_gifti(gifti_type, filename, data, hemisphere, additional_metadata)
%
% Create and save a metric or surface gifti file. Generally most useful
% when called from saveimgfile.m
%--------------------------------------------------------------------------
% 
% Inputs: 
%       gifti_type: (obligatory)
%           The type of gifti file to be made
%           {'surf', 'func', 'shape'}
%           May add more types later
%       filename: (obligatory)
%           Full path and file name of a gifti file (.gii extension)
%       data: (obligatory)
%           The data to be put into the gifti. For a surf gifti this should
%           be in the format data.vertices and data.faces. For a metric
%           gifti, only a vector in data is required
%       hemisphere: (obligatory)
%           {'L', 'R', 'left'. 'right'}
%           This will be used to set the AnatomicalStructurePrimary and, if
%           necessary to prepend lh. or rh. to the filename
%       additonal_metadata (optional) 
%        	Any other key: value pairs that you want to add to the
%        	metadata. This should be in the format metadata.my_key =
%        	'something or other'
%
% Calls: make_empty_gifti, save_gifti
%
% Version history
% 18-10-2018    Rogier          change time stamp to increase compatibility
% 27-04-2018    Rogier          changed use of contrains to strcontain
% 26-04-2018    Rogier          changed output file convention to not
%                               automatically start with hemisphere
% 20-04-2018    Rogier          commented out comment to screen
% 19-04-2018    Martin/Rogier   remove bugs following testing (Martin) and
%                               polished documentation for move to general
%                               MrCat folder (Rogier)
% Early 2018    Martin          created
%
% copyright
% Martin Guthrie/Rogier B. Mars
% University of Oxford & Donders Institute, 2015-2018
%--------------------------------------------------------------------------

% Additional information:
% A gifti file is loaded using load_gifti.m. This returns a structure. For
% metric files, there is one (or possibly more) data array(s) in the structure, 
% for the vertices. From the GIFTI surface format
% (https://www.nitrc.org/projects/gifti/):
% 13.2 Functional File
% The functional file contains one or more DataArrays with Intent set to
% NIFTI_INTENT_NONE or one of the statistical intent values. Each
% DataArray has DataType set to NIFTI_TYPE_FLOAT32. Dimensionality is
% one with the first dimension set to the number of nodes. 
% 13.4 Shape File
% The shape file contains one or more DataArrays with Intent set to
% NIFTI_INTENT_SHAPE and DataType set to NIFTI_TYPE_FLOAT32.
% Dimensionality is one with the first dimension set to the number of nodes.
% 13.7 Topology File
% The Topology File contains one DataArray with Intent set to NIFTI_INTENT_TRIANGLE 
% and DataType set to NIFTI_TYPE_INT32. Dimensionality is two with the first 
% dimension set to the number of triangles and the second dimension set to three. 
% Each triplet consists of node indices that, along with the corresponding 
% Coordinate File, form the triangles of the surface model.
% I think this means that the coordinate file holds the vertices and the
% topology file holds the faces, although it is not clear. That means that
% the first data array in a surface file should be vertices
%--------------------------------------------------------------------------

[a_path, a_file, an_ext] = get_image_file_parts(filename);
% Add in the correct file extension if the user has not specified it
if ~strcontain(an_ext, 'gii')
    an_ext = strcat(an_ext, '.', 'gii');
end
% Make sure that the gifti type is in the file name
if ~strcontain(an_ext, gifti_type)
    an_ext = strcat('.', gifti_type, an_ext);
end

gifti_struct = make_empty_gifti(gifti_type);

if nargin == 5
    % Additional metadata has been specified as a struct e.g.
    % additional_metadata.ScannerName = 'Bruker'
    gifti_struct.MetaData = additional_metadata;
end

% gifti_struct.MetaData.Created = datestr(datetime('now'));
gifti_struct.MetaData.Created = datestr(now);

% AnatomicalStructurePrimary can contain other values (see the gifti
% specification at www.nitric.org for more information). For the moment
% assume we are working with just the two cortices
s_hemis = {'CortexLeft', 'CortexRight'};
s_hemis_short = {'lh.', 'rh.'};

switch upper(hemisphere)
    % Where the AnatomicalStructurePrimary is stored depends on the type of
    % gifti
    case {'L', 'LEFT'}
        s_anat_struct = char(s_hemis(1));
        if ~strcontain(a_file, char(s_hemis_short(1)))
            % prepend the hemsiphere to the file name
            filename = fullfile(a_path, strcat(a_file, an_ext));
            % filename = fullfile(a_path, strcat(char(s_hemis_short(1)), a_file, an_ext));
        end
    case {'R', 'RIGHT'}
        s_anat_struct = char(s_hemis(2));
        if ~strcontain(a_file, char(s_hemis_short(2)))
            % prepend the hemsiphere
            filename = fullfile(a_path, strcat(a_file, an_ext));
            % filename = fullfile(a_path, strcat(char(s_hemis_short(2)), a_file, an_ext));
        end
end

   
if strcmpi(gifti_type, 'surf')
    % Then both the vertices and faces are stored in the structure data
    for i = 1:2
        switch gifti_struct.DataArray{i}.Intent
            % The first data array always contains the spatial information
            % (coordinates) for the vertices
            case 'NIFTI_INTENT_POINTSET'
                % check that the data is an array of single
                d_type = class(data.vertices);
                if ~strcmpi(d_type, 'single')
                    % If not, typecast it
                    data.vertices = single(data.vertices);
                end
                gifti_struct.DataArray{i}.Data = data.vertices;
                [Dim0, ~] = size(data.vertices);
                % Dim1 is alwasy 3 and is set in make_empty_gifti
                gifti_struct.DataArray{i}.Dim0 = num2str(Dim0);
                % Surf files do not have the AnatomicalStructurePrimary in the main
                % metadata but in the metadata for the vertices for some reason
                gifti_struct.DataArray{i}.MetaData.AnatomicalStructurePrimary = s_anat_struct;
            % The second data array always contains the indices of the 3 vertex
            % coordinates from the NIFTI_INTENT_POINTSET that make up a triangle
            case 'NIFTI_INTENT_TRIANGLE'
                % check that the data is an array of single
                d_type = class(data.faces);
                if ~strcmpi(d_type, 'int32')
                    % If not, typecast it
                    data.faces = int32(data.faces);
                end
                gifti_struct.DataArray{i}.Data = data.faces;
                [Dim0, ~] = size(data.faces);
                % Dim1 is alwasy 3 and is set in make_empty_gifti
                gifti_struct.DataArray{i}.Dim0 = num2str(Dim0);
        end
    end
else
    % It is a metric file (func or shape)
    gifti_struct.MetaData.AnatomicalStructurePrimary = s_anat_struct;
    % check that the data is an array of single
    d_type = class(data);
    if ~strcmpi(d_type, 'single')
        data = single(data);
    end
    gifti_struct.DataArray{1}.Data = data;
    Dim0 = length(data);
    gifti_struct.DataArray{1}.Dim0 = num2str(Dim0);
end

op_file = filename;
save_gifti(gifti_struct, op_file);

% fprintf('%s gifti saved to %s\n', gifti_type, op_file);

end