function gifti_struct = make_empty_gifti(gifti_type)
% function gifti_struct = make_empty_gifti(gifti_type)
% 
% This function creates a gifti structure without any data values. This empty
% structure is then returned and the attributes can then be added in
% standard Matlab manner. It is most useful when called by create_gifti.m
%--------------------------------------------------------------------------
%
% Inputs:
%       gifti_type = {'surf', 'func', 'shape'}
% Outputs:
%       gifti_struct: A Matlab data structure as follows
% 
%        Version 
%         NumberOfDataArrays
%         MetaData
%             Name, value data pairs
%         DataArray
%             MetaData
%                 Name, value data pairs of common elements
%             CoordinateSystemTransformationMatrix
%                 DataSpace
%                 TransformationSpace
%                 MatrixData
%             Data
%         LabelTable
%             Label
%                 LabelName
%                 Attributes
%                     Key
%                     Red
%                     Green
%                     Blue
%                     Alpha
%
% Version history
% 20-04-2018    Rogier  Prepared for move to MrCat/general
% Martin Guthrie      v1.0       2018-02-05
%
% copyright
% Martin Guthrie/Rogier B. Mars
% University of Oxford & Donders Institute, 2015-2018
%--------------------------------------------------------------------------

% Additional documentation:
%
% From the GIFTI surface format
% (https://www.nitrc.org/projects/gifti/):
% 13.1 Coordinate File
% The coordinate file contains one DataArray with Intent set to NIFTI_INTENT_POINTSET 
% and DataType set to NIFTI_TYPE_FLOAT32. Dimensionality is two with the first 
% dimension set to the number of nodes and the second dimension set to three. 
% This DataArray contains the X-, Y-, and Z-Coordinate for each node.
% 13.2 Functional File
% The functional file contains one or more DataArrays with Intent set to
% NIFTI_INTENT_NONE or one of the statistical intent values. Each
% DataArray has DataType set to NIFTI_TYPE_FLOAT32. Dimensionality is
% one with the first dimension set to the number of nodes. 
% 13.4 Shape File
% The shape file contains one or more DataArrays with Intent set to
% NIFTI_INTENT_SHAPE and DataType set to NIFTI_TYPE_FLOAT32.
% Dimensionality is one with the first dimension set to the number of nodes.
% 13.5 Surface File
% The surface file contains two DataArrays. The first DataArray is identical 
% to the DataArray in a Coordinate File and the second DataArray is identical 
% to the DataArray in a Topology File.
%--------------------------------------------------------------------------

metric_types = ['func', 'shape'];
gifti_struct.Version = '1.0';

if strcmpi(gifti_type, 'surf')
    gifti_struct.NumberOfDataArrays = '2';
    % For surface files only, there are two data arrays
    for i = 1:2
        % Put in default values for the fields that are required
        % ArrayIndexingOrder = 'RowMajorOrder' || 'ColumnMajorOrder'
        data_array.ArrayIndexingOrder = 'RowMajorOrder';
        % User needs to set the size of Dim0 and Dim1 based on the size of
        % the data arrays that they will be loading
        data_array.Dim0 = '';
        % Dim1 is always 3
        data_array.Dim1 = '3';
        data_array.Dimensionality = '2';
       % Encoding = 'ASCII' || 'Base64Binary' || 'GZipBase64Binary' ||
       % ExternalFileBinary'
        data_array.Encoding = 'GZipBase64Binary';
        % Endian = 'BigEndian' || 'LittleEndian'
        data_array.Endian = 'LittleEndian';
        data_array.ExternalFileName = '';
        data_array.ExternalFileOffset = '';
        data_array.MetaData = [];
        
        data_array.CoordinateSystemTransformationMatrix.Dataspace = 'NIFTI_XFORM_UNKNOWN';
        data_array.CoordinateSystemTransformationMatrix.TransformedSpace = 'NIFTI_XFORM_UNKNOWN';
        % Set it to the identity array
        data_array.CoordinateSystemTransformationMatrix.MatrixData = eye(4);
        
        data_array.Data = [];
        
        DataArray{i} = data_array;
        
    end
    % The first data array always contains the spatial information
    % (coordinates) for the vertices
    DataArray{1}.Intent = 'NIFTI_INTENT_POINTSET';
    % DataType = 'NIFTI_TYPE_UINT8' || 'NIFTI_TYPE_INT32' ||
    % 'NIFTI_TYPE_FLOAT32'
    % For NIFTI_INTENT_POINTSET it is the vertices of the triangles, so it
    % must be a float
    DataArray{1}.DataType = 'NIFTI_TYPE_FLOAT32';
    % The second data array always contains the indices of the 3 vertex
    % coordinates from the NIFTI_INTENT_POINTSET that make up a triangle
    DataArray{2}.Intent = 'NIFTI_INTENT_TRIANGLE';
    % DataType = 'NIFTI_TYPE_UINT8' || 'NIFTI_TYPE_INT32' ||
    % 'NIFTI_TYPE_FLOAT32'
    DataArray{2}.DataType = 'NIFTI_TYPE_INT32';
    
    % The MetaData is different for the two data arrays
    DataArray{1}.MetaData.GeometricType = 'Anatomical';
    % The AnatomicalStructurePrimary and AnatomicalStructureSecondary can
    % be determined from the file name when saving the gifti
    DataArray{1}.MetaData.AnatomicalStructurePrimary = 'Unknown';
    DataArray{1}.MetaData.AnatomicalStructureSecondary = 'Unknown';
    DataArray{2}.MetaData.TopologicalType = 'Closed';
    
elseif ismember(lower(gifti_type), metric_types)
    gifti_struct.NumberOfDataArrays = '1';
    % For metric files there is only one data array
    % Put in default values for the fields that are required
    % ArrayIndexingOrder = 'RowMajorOrder' || 'ColumnMajorOrder'
    DataArray{1}.ArrayIndexingOrder = 'RowMajorOrder';
    DataArray{1}.DataType = 'NIFTI_TYPE_FLOAT32';
    % User needs to set the size of Dim0 based on the size of
    % the data array that they will be loading
    DataArray{1}.Dim0 = [];
    DataArray{1}.Dimensionality = '1';
   % Encoding = 'ASCII' || 'Base64Binary' || 'GZipBase64Binary' ||
   % ExternalFileBinary'
    DataArray{1}.Encoding = 'GZipBase64Binary';
    % Endian = 'BigEndian' || 'LittleEndian'
    DataArray{1}.Endian = 'LittleEndian';
    DataArray{1}.ExternalFileName = '';
    DataArray{1}.ExternalFileOffset = '';
    if strcmpi(gifti_type, 'func') 
        DataArray{1}.Intent = 'NIFTI_INTENT_NONE'; % This is only true for func files
    elseif strcmpi(gifti_type, 'shape') 
        DataArray{1}.Intent = 'NIFTI_INTENT_SHAPE'; % This is only true for shape files
    end    
    DataArray{1}.MetaData = [];
else
    error('gifti type must be surf or metric');
end

LabelTable = struct;
LabelTable.Label.LabelName = [];
LabelTable.Label.Attributes = [];

gifti_struct.MetaData = [];
gifti_struct.DataArray = DataArray;
gifti_struct.LabelTable = LabelTable;
                       

end