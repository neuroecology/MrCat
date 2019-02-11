function gifti_struct = load_gifti(ip_file)
% function gifti_struct = load_gifti(ip_file)
%
% Reads in a .gii file and returns the data in it as a structure. Best used
% as part of readimgfile.m; called by load_gifti_data.m
%--------------------------------------------------------------------------
%
% Inputs:
%       ip_file: (obligatory) Full file name of the gifti file, including path
%
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
% Usage:
%     ip_file = fullfile(filesep, 'path', 'to', 'a', 'gifti', 'a_gifti.gii');
%     gifti_struct = load_gifti(ip_file);
%
% Data in gifti files created by mris_convert is stored as base 64 binary
% encoded and zipped. This is obviously not a useful format to keep for the
% data structure. So the data is unzipped and translated to a matrix using
% the dimensions stored in the DataArray.MetaData.
% Similarly the MatrixData has to be translated from a single string to a
% 4x4 array of doubles.

% Sections of the code, including  the data transformation, have been taken
% from the gifti.m class of Guillaume Flandin
% https://github.com/nno/matlab_GIfTI

% Martin Guthrie (2016)

% Version history
% 20-04-2018    Rogier          Polished for move to MrCat/general
% 08-02-2018    Martin/Rogier   Fixed 'end' issue   2018-02-08
% Martin Guthrie      v1.0              2018-02-05
%
% copyright
% Martin Guthrie/Rogier B. Mars
% University of Oxford & Donders Institute, 2015-2018
%--------------------------------------------------------------------------

% Additional documentation:
%
% The structure conforms to the GIFTI surface data format in
% Harwell et al (2011).
% See http://www.nitrc.org/projects/gifti/ for further details
% Note that there is an error in the specification. In the diagram on page
% 4, there is reference to CoordinateSystemTransformationMatrix. Throughout
% the rest of the document and in all gifti files that I have seen this
% element is named CoordinateSystemTransformMatrix
%--------------------------------------------------------------------------

% Main code section

    if ~exist(ip_file, 'file')
        error('load_gifti: input file not found');
    end

    % Get the top node
    x_doc = load_xml(ip_file);
    x_root = x_doc.getDocumentElement;
    file_type = x_root.getNodeName;
    if ~strcmpi(file_type, 'GIFTI')
        error('A valid GIFTI file should contain ''GIFTI'' at the start of the root node');
    end
    % The version must be in a top level tag. At present this is always 1.0
    gifti_struct.Version = char(x_root.getAttribute('Version'));
    if strcmpi(gifti_struct.Version, '')
        error('The version number is a mandatory attribute for a valid GIFTI file');
    end

    % Another required attribute
    gifti_struct.NumberOfDataArrays = char(x_root.getAttribute('NumberOfDataArrays'));
    if strcmpi(gifti_struct.NumberOfDataArrays, '')
        error('The number of data arrays is a mandatory attribute for a valid GIFTI file');
    end

    gifti_struct.name_space = char(x_root.getAttribute('xmlns:xsi'));

    gifti_struct.schema_location = char(x_root.getAttribute('xsi:noNamespaceSchemaLocation'));

    top_nodes = x_root.getChildNodes;
    % Might be 2 data arrays
    i_data_array = 1;

    for i = 0 : top_nodes.getLength - 1
        a_node = top_nodes.item(i);
        switch upper(get_node_name(a_node))
            case 'CONTENT'
                continue;
            case 'METADATA'
                MetaData = [];
                gifti_struct.MetaData = get_metadata(MetaData, a_node.getChildNodes);
            case 'DATAARRAY'
                gifti_struct.DataArray{i_data_array} = get_data_array(a_node.getChildNodes);
                i_data_array = i_data_array + 1;
            case 'LABELTABLE'
                gifti_struct.LabelTable = get_label_table(a_node.getChildNodes);
        end
    end

    % Check in case the CoordinateSystmeTransformationMatrix is missing
    gifti_struct.DataArray = check_coordinate_system(ip_file, x_doc, gifti_struct.DataArray);

end

%%
% This function gives an easy way to ignore the empty #text nodes that
% Matlab's (Saxon) xml engine inserts for some reason
% See https://www.w3schools.com/xml/dom_nodetype.asp
function [node_name] = get_node_name(a_node)

    % get node name and make sure it is a valid variable name in Matlab.
    switch (a_node.getNodeType)
        case a_node.ELEMENT_NODE
            % This is a named constant in xml. It is what we are looking for
            % here
            node_name = char(a_node.getNodeName);% capture name of the node
        case a_node.TEXT_NODE
            node_name = 'CONTENT';
        case a_node.COMMENT_NODE
            node_name = 'COMMENT';
        case a_node.CDATA_SECTION_NODE
            node_name = 'CDATA_SECTION';
        case a_node.DOCUMENT_TYPE_NODE
            node_name = 'DOCUMENT_TYPE';
        case a_node.PROCESSING_INSTRUCTION_NODE
            node_name = 'PROCESSING_INSTRUCTION';
        otherwise
            NodeType = {'ELEMENT','ATTRIBUTE','TEXT','ENTITY_REFERENCE', 'ENTITY', ...
                'DOCUMENT', 'DOCUMENT_FRAGMENT', 'NOTATION'};
            node_name = char(a_node.getNodeName);% capture name of the node
            warning('xml_io_tools:read:unkNode', ...
                'Unknown node type encountered: %s_NODE (%s)', NodeType{a_node.getNodeType}, node_name);
    end
end

%%
% MetaData occurs in two different places in the gifti specification,
% at the top level and under the DataArray
% Files created using mris_convert have the following metadata structure:
%   <MetaData>
%       <MD>
%           <Name
%               <![CDATA[ UserName ]]>
%           </Name>
%           <Value>
%               <![CDATA[ mguthrie ]]>
%           </Value>
%       </MD>
%   </Metadata>
% Files created using mri_convert have a different metadata structure:
%   <MetaData>
%       <MD>
%           <item>
%               <Name>UserName</Name>
%               <Value>mguthrie</Value>
%           </item>
%       </MD>
%   </Metadata>
function [MetaData] = get_metadata(MetaData, md_nodes)

     if md_nodes.hasChildNodes
        value_data = [];
        for i = 0: md_nodes.getLength - 1
            md_node = md_nodes.item(i);
            switch upper(get_node_name(md_node))
                case 'CONTENT'
                     continue;
                case 'NAME'
                    % MetaData comes in pairs. Under each penultimate node is a
                    % Name and a Value node
                    md_names = md_node.getChildNodes;
                    % If there is more than one child node, there is
                    % something wrong with the xml
                    % Field names cannot have certain characters, such as -
                    % makeValidName changes invalid characters for valid
                    % ones
                    name_data = matlab.lang.makeValidName(char(md_names.getTextContent));
                    MetaData.(name_data) = value_data;
                case 'VALUE'
                    md_values = md_node.getChildNodes;
                    % Field values can contain any characters
                   value_data = char(md_values.getTextContent);
                    MetaData.(name_data) = value_data;
                otherwise
                    % Not deep enough yet, try the next level
                    [MetaData] = get_metadata(MetaData, md_node);
            end
        end
     end
end

%%
% The DataArray part of the structure has 3 fields: Metadata, Data and
% CoordinateSystemTransformMatrix

function [DataArray] = get_data_array(da_nodes)

    if da_nodes.hasAttributes
        % The attributes are called common elements in the gifti spec
        da_attributes = da_nodes.getAttributes;
        for i = 0: da_attributes.getLength - 1
            an_attribute = da_attributes.item(i);
            attribute_name = char(an_attribute.getNodeName);
            attribute_value = char(an_attribute.getNodeValue);
            if isempty(attribute_value)
                attribute_value = '';
            end
            DataArray.(attribute_name) = attribute_value;
        end
    end

    for i = 0 : da_nodes.getLength - 1
        da_node = da_nodes.item(i);
        switch upper(get_node_name(da_node))
            case 'CONTENT'
                continue;
            case 'METADATA'
                DataArray.MetaData = [];
                DataArray.MetaData = get_metadata(DataArray.MetaData, da_node.getChildNodes);
            case 'COORDINATESYSTEMTRANSFORMMATRIX'
                CoordinateSystemTransformMatrix = [];
                DataArray.CoordinateSystemTransformMatrix = get_transformation_matrix(CoordinateSystemTransformMatrix, da_node.getChildNodes);
            case 'DATA'
                gifti_data = get_gifti_data(da_node);
                DataArray = decode_data(DataArray, gifti_data);
        end
    end
 end

%%
% Go recursively until you get to the leaf node then pass back the only
% field there

function [gifti_data] = get_gifti_data(data_node)

    if data_node.hasChildNodes
        if data_node.getLength > 1
            error('Data nodes should only ever have one child');
        else
            gifti_data = get_gifti_data(data_node.item(0));
        end
    else
        gifti_data = char(data_node.getData);
    end

end

%%
% The data from giftis that have been created by mris_convert seem to
% always be encoded as base 64 binary and then gzipped.
% The data is stored in a single vector. The number of dimensions that the
% data should be in is stored in the DataArray attribute Dimensionality

function [DataArray] = decode_data(DataArray, ip_data)

    % Get the data type of the encoded data to do the type casting
    switch upper(DataArray.DataType)
        case 'NIFTI_TYPE_UINT8'
            cast_to = 'uint8';
        case 'NIFTI_TYPE_INT32'
            cast_to = 'int32';
        case 'NIFTI_TYPE_FLOAT32'
            cast_to = 'single';
        case 'NIFTI_TYPE_FLOAT64'
            cast_to = 'double';
    end

    switch upper(DataArray.Encoding)
        case 'ASCII'
            d = feval(tp.conv,sscanf(xml_get(t,xml_children(t,uid),'value'),tp.format));

        case upper('Base64Binary')
            ip_data = base64decode(ip_data);
            ip_data = typecast(ip_data, cast_to);

        case upper('GZipBase64Binary')
            byte_stream = base64decode(ip_data);
            ip_data = zstream('D', byte_stream);
            ip_data = typecast(ip_data, cast_to);

        case upper('ExternalFileBinary')
            % Not dealing with external files for the moment
%             [p,f,e] = fileparts(s.ExternalFileName);
%             if isempty(p)
%                 s.ExternalFileName = fullfile(pwd,[f e]);
%             end
%             if true
%                 fid = fopen(s.ExternalFileName,'r');
%                 if fid == -1
%                     error('[GIFTI] Unable to read binary file %s.',s.ExternalFileName);
%                 end
%                 fseek(fid,str2double(s.ExternalFileOffset),0);
%                 d = sb(fread(fid,prod(s.Dim),['*' tp.class]));
%                 fclose(fid);
%             else
%                 d = file_array(s.ExternalFileName, s.Dim, tp.class, ...
%                     str2double(s.ExternalFileOffset),1,0,'rw');
%             end
%
        otherwise
            error('[GIFTI] Unknown data encoding: %s.',s.Encoding);
    end

    % The data is in one long string. We want it as a matrix with the
    % nubmer of dimensions specified in the DataArray attribute
    % Dimensionality
    dim_count = str2num(DataArray.Dimensionality);
    if dim_count > 1
        for i = 1: dim_count
            s_dim = sprintf('Dim%d', dim_count-i);
            dimensions(i) = str2num(['int32(' DataArray.(s_dim) ')']);
        end

        % Reshape the vector of data to the correct number of dimensions
        % (usually one or two)
        switch DataArray.ArrayIndexingOrder
            case 'RowMajorOrder'
                reshaped = reshape(ip_data,dimensions);
                order = length(dimensions):-1:1;
                DataArray.Data = permute(reshaped, order);
            case 'ColumnMajorOrder'
                DataArray.Data = reshape(ip_data,dimensions);
            otherwise
                error('[GIFTI] Unknown array indexing order.');
        end
    else
        DataArray.Data = ip_data;
    end
end

%%
%

function [LabelTable] = get_label_table(label_nodes)

    LabelTable = [];
    if label_nodes.hasChildNodes
        for i = 0: label_nodes.getLength - 1
            label_node = label_nodes.item(i);
            % Keep track of how many labels you have foound
            switch upper(get_node_name(label_node))
                case 'CONTENT'
                     continue;
                case 'LABEL'
                    a_label = label_node.getChildNodes;
                    if a_label.hasAttributes
                        % Each label has some text showing it's position in
                        % the brain
                        label_name = char(a_label.getTextContent);
                        % Reset this just in case there is no Key attribute
                        label_number = -1;
                        % Each label should have 5 attriibutes
                        label_attributes = a_label.getAttributes;

                        for j = 1: label_attributes.getLength
                            an_attribute = label_attributes.item(j-1);
                            attribute_name{j} = char(an_attribute.getNodeName);
                            attribute_value{j} = char(an_attribute.getNodeValue);
                            if isempty(attribute_value{j})
                                attribute_value{j} = '';
                            end
                            % Each value in the key attribute should be
                            % unique for that label
                            if strcmpi(attribute_name{j}, 'KEY')
                                % Must be 1 based to use in struct array
                                label_number = str2num(attribute_value{j}) + 1;
                            end
                        end
                        if label_number == -1
                            warning('GIFTI: Label %s did not have a key value so cannot be placed in the LabelTable', ...
                                        label_name);
                        end

                        % Now go through the attributes that we have
                        % loaded and add them in the correct position in
                        % the LabelTable array
                        LabelTable(label_number).Name = label_name;
                        for j = 1: label_attributes.getLength
                            LabelTable(label_number).(attribute_name{j}) = attribute_value{j};
                        end
                    end
                otherwise
                    % Not deep enough yet, try the next level
                    [LabelTable] = get_lable_table(LabelTable, label_node);
            end
        end
     end
end

%%
% Get the CoordinateSystmeTransformationMatrix

function [CoordinateSystemTransformMatrix] = get_transformation_matrix(CoordinateSystemTransformMatrix, tm_nodes)

    if tm_nodes.hasChildNodes
        for i = 0: tm_nodes.getLength - 1
            tm_node = tm_nodes.item(i);
            switch upper(get_node_name(tm_node))
                case 'CONTENT'
                   continue;
                case 'DATASPACE'
                    tm_dataspaces = tm_node.getChildNodes;
                    % There should only be one node
                    CoordinateSystemTransformMatrix.DataSpace = char(tm_dataspaces.getTextContent);
                case 'TRANSFORMEDSPACE'
                    tm_transformed_spaces = tm_node.getChildNodes;
                    CoordinateSystemTransformMatrix.TransformedSpace = char(tm_transformed_spaces.getTextContent);
               case 'MATRIXDATA'
                    tm_matrix_data_node = tm_node.getChildNodes;
                    tm_matrix_data = tm_matrix_data_node.item(0);
                    % The matrix data is a 4 x 4 array, but stored as a
                    % string with spaces between numbers and line returns
                    % every 4th number
                    s_matrix_data = char(tm_matrix_data.getData);
                    CoordinateSystemTransformMatrix.MatrixData = str2num(s_matrix_data);
                otherwise
                    % Not deep enough yet, try the next level
                    [CoordinateSystemTransformMatrix] = get_transformation_matrix(CoordinateSystemTransformMatrix, tm_node);
            end
        end
    end

end

%%
% Some files seem to be missing the CoordinateSystemTransformMatrix.
% This causes  a problem when reading into workbench, so put an artificial
% matrix in and save it to the xml file as well.

function [DataArray] = check_coordinate_system(ip_file, top_node, DataArray)

% The xml in this section should look something like this
% <CoordinateSystemTransformMatrix>
%  <DataSpace><![CDATA[NIFTI_XFORM_UNKNOWN]]></DataSpace>
%  <TransformedSpace><![CDATA[NIFTI_XFORM_UNKNOWN]]></TransformedSpace>
%  <MatrixData>1.000000 0.000000 0.000000 0.000000 0.000000 1.000000
% 0.000000 0.000000 0.000000 0.000000 1.000000 0.000000 0.000000 0.000000
% 0.000000 1.000000 </MatrixData>
% </CoordinateSystemTransformMatrix>

    for i = 1: length(DataArray)
        if strcmpi(DataArray{1,i}.Intent, 'NIFTI_INTENT_POINTSET')
            % Only need a CoordinateSystemTransformMatrix for this type of
            % data
            a_node = top_node.getElementsByTagName('CoordinateSystemTransformMatrix');
            if isempty(a_node)  || (a_node.getLength == 0)
                da_nodes = top_node.getElementsByTagName('DataArray');
                da_node = da_nodes.item(0);
                % Add a CoordinateSystemTransformMatrix node
                coord_node = top_node.createElement('CoordinateSystemTransformMatrix');
                da_node.appendChild(coord_node);

                % Add the other nodes under the CoordinateSystemTransformMatrix
                % node
                data_space_node = top_node.createElement('DataSpace');
                data_space_text = top_node.createTextNode('![CDATA[ NIFTI_XFORM_UNKNOWN ]');
                coord_node.appendChild(data_space_node);
                data_space_node.appendChild(data_space_text);

                transformed_space_node = top_node.createElement('TransformedSpace');
                transformed_space_text = top_node.createTextNode('![CDATA[ NIFTI_XFORM_UNKNOWN ]');
                coord_node.appendChild(transformed_space_node);
                transformed_space_node.appendChild(transformed_space_text);

                % Make a fake array for the matrix data. The data in it is probably
                % incorrect so just use an identity matrix
                matrix_data = eye(4);
                cstm_node = top_node.createElement('MatrixData');
                cstm_node_text = top_node.createTextNode(mat2str(matrix_data));
                coord_node.appendChild(cstm_node);
                cstm_node.appendChild(cstm_node_text);

                xmlwrite(ip_file, top_node);

                % Also save the data to the data structure that is being loaded
                DataArray{1,i}.CoordinateTransformSystemMatrix.DataSpace = 'NIFTI_XFORM_UNKNOWN';
                DataArray{1,i}.CoordinateTransformSystemMatrix.TransformedSpace = 'NIFTI_XFORM_UNKNOWN';
                DataArray{1,i}.CoordinateTransformSystemMatrix.MatrixData = matrix_data;
            end
        end
    end
end
