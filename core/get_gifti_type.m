function gifti_type = get_gifti_type(ip_file)
% function gifti_type = get_gifti_type(ip_file)
%
% Work out what type of gifti file has been sent from the filename. Called by
% load_gifti_data.m
%--------------------------------------------------------------------------
%
% Inputs:
%   ip_file: The filename including path of the gifti that has been modified
%
% Outputs:
%  gifti_type: a string containing the file type specified in types below
%
%  Usage:
%     dir_subject = fullfile(file_sep,'path','to', 'subject', 'structural', 'image');
%     dir_surf = fullfile(dir_subject, 'surf');
%     ip_file = fullfile(dir_surf, 'lh.inflated.surf.gii');
%     gifti_type = get_gifti_type(ip_file)
%
% Version history
% 17-04-2018    Rogier  Polish for MrCat and commented
% 05-02-2018    Martin  Created
%--------------------------------------------------------------------------

% The valid types. See p32 of the gifti spec at https://www.nitrc.org/projects/gifti/
types = {'surf', 'func', 'shape', 'coord', 'label', 'rgba', 'tensor', 'time', 'topo', 'vector'};

[~, filename, ext] = fileparts(ip_file);
if ~strcmpi(ext, '.gii')
    error('%s is not a valid gifti file', ip_file);
end

dots = strfind(filename, '.');
% The bit just before the .gii is the file type. So the last part of the
% filename.
gifti_type = filename(dots(end)+1:end);

if ~ismember(gifti_type, types)
    error('Error in MrCat:get_gifti_type: %s is not in the set of recognized gifti types', ip_file);
end
