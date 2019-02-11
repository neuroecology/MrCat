function save_gifti(gifti_struct, op_file)
% function save_gifti(gifti_struct, op_file)
%
% Save a gifti struct
%--------------------------------------------------------------------------
%
% Inputs:
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
%       op_file: Full file name and path to save the giftt to. This should
%       include the gifti type (e.g. surf) in the file name and have an
%       extension .gii
%
% Version history
% 20-04-2018    Rogier  commented out comments to screen
% 18-04-2018    Martin  removed calls to extractfield and fixed bug
%                       following Rogier testing
% early 2018    Martin 	created
%--------------------------------------------------------------------------

% Start creating an xml structure
doc_node = com.mathworks.xml.XMLUtils.createDocument('GIFTI');
dom_impl = doc_node.getImplementation();
doc_type = dom_impl.createDocumentType('GIFTI', 'SYSTEM', 'http://gifti.projects.nitrc.org/gifti.dtd');
doc_node.appendChild(doc_type);

doc_spec = doc_node.getDocumentElement;
if isfield(gifti_struct, 'NumberOfDataArrays')
    doc_spec.setAttribute('NumberOfDataArrays', gifti_struct.NumberOfDataArrays);
else
    error('The NumberOfDataArrays is a compulsory field');
end
if isfield(gifti_struct, 'Version')
    doc_spec.setAttribute('Version', gifti_struct.Version);
else
    % Put Version = 1.0 in anyway. I've never seen anything different
    doc_spec.setAttribute('Version', '1.0');
end

% Put in the top level MetaData. This is not the same as the MetaData
% associated with each DataArray
metadata_node = doc_node.createElement('MetaData');
doc_spec.appendChild(metadata_node);

% Then add the MDs in for each Name:Value pair of metadata. E.g.,
% <MD>
% <Name>UserName</Name>
% <Value>mguthrie</Value>
% </MD>
MDs = fieldnames(gifti_struct.MetaData);
for i = 1: numel(MDs)
    s_name = char(MDs(i));
    s_value = gifti_struct.MetaData.(s_name);
%     s_name = MDs(i);
%     s_value = extractfield(gifti_struct.MetaData, char(s_name));
    add_md_node(doc_node, metadata_node, s_name, s_value);
end

% Add in the data arrays, with their attributes and metadata
for i = 1: str2double(gifti_struct.NumberOfDataArrays)
    data_array_node = doc_node.createElement('DataArray');
    doc_spec.appendChild(data_array_node);
    da_attr = fieldnames(gifti_struct.DataArray{i});
    for j = 1: numel(da_attr)
        s_name = char(da_attr(j));
        if strcmpi(s_name, 'MetaData')
            % It looks like a MetaData node is created even if there is not
            % metadata for the data array
            metadata_node = doc_node.createElement('MetaData');
            data_array_node.appendChild(metadata_node);
            if ~isempty(gifti_struct.DataArray{i}.MetaData)
                MDs = fieldnames(gifti_struct.DataArray{i}.MetaData);
                for k = 1: numel(MDs)
                   md_name = char(MDs(k));
                   md_value = gifti_struct.DataArray{i}.MetaData.(md_name);
%                    md_name = MDs(k);
%                     md_value = extractfield(gifti_struct.DataArray{i}.MetaData, char(md_name));
                    add_md_node(doc_node, metadata_node, md_name, md_value);
                end
            end
        elseif strcmpi(s_name, 'Data')
            data_node = doc_node.createElement('Data');
            data_array_node.appendChild(data_node);
            set_data(data_node, gifti_struct.DataArray{i});
        elseif strcmpi(s_name, 'CoordinateSystemTransformationMatrix')
            continue;
        else
            % All the other attributes of the data array
            s_value = gifti_struct.DataArray{i}.(s_name);
%            s_value = char(extractfield(gifti_struct.DataArray{i}, char(s_name)));
            data_array_node.setAttribute(s_name, s_value);
        end
    end
end

% fprintf('Writing to %s\n', op_file);
xmlwrite(op_file, doc_node);

end

% MD nodes are added under the MetaData tag. This can either be at the top
% level or under the DataArray tag
% Each MD node has two tags under it, Name and Value, containing the actual
% metadata
function add_md_node(doc_node, parent_node, what_name, what_value)

        md_node = doc_node.createElement('MD');
        parent_node.appendChild(md_node);

        name_node = doc_node.createElement('Name');
        name_node.setTextContent(what_name);
        md_node.appendChild(name_node);

        value_node = doc_node.createElement('Value');
        value_node.setTextContent(what_value);
        md_node.appendChild(value_node);

end
    
function set_data(da_node, attributes)

    switch upper(attributes.DataType)
        case 'NIFTI_TYPE_UINT8'
            cast_to = 'uint8';
        case 'NIFTI_TYPE_INT32'
            cast_to = 'int32';
        case 'NIFTI_TYPE_FLOAT32'
            cast_to = 'single';
        case 'NIFTI_TYPE_FLOAT64'
            cast_to = 'double';
    end
    
    if strcmpi(attributes.Dimensionality, '2')
        % The data is in a matrix with the number of dimensions specified in 
        % the DataArray attribute. Need to convert it to a long vector either
        % row-by-row or column-by-column depending on the value of
        % ArrayIndexingOrder
        new_dim = size(attributes.Data);
        % Get the length of the expected vector
        str_length = new_dim(1) * new_dim(2);
        % Use the inverse of the data to reshape because Matlab reshapes on a
        % column basis
        new_data = reshape(attributes.Data', str_length, 1);
    else
        % The data is just a vector
        new_data = attributes.Data;
    end
    
   encoded_data = encode_data(new_data, cast_to);
   da_node.setTextContent(encoded_data);
    
end

% For the moment assume that the data has to be encoded as
% GZipBase64Binary. I could check this by looking at the DataArray
% attributes, but I have never seen anything else
function encoded_data = encode_data(raw_data, cast_to)    

    encoded_data = base64encode(zstream('C',typecast(raw_data(:),cast_to)));
    
end