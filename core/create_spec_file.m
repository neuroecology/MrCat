function create_spec_file(varargin)
% function create_spec_file(varargin)
%
% Write a spec file for workbench
%
% First input is spec file name string, other inputs are series of three strings
% per image that is supposed to be part of the spec file:
%   (1)     'L' or 'R'
%   (2)     filetype ('SURFACE','METRIC',VOLUME',CONNECTIVITY_DENSE)
%   (3)     filename including extension)
%
% Example usage: create_spec_file('test.wb.spec','L','SURFACE','HCP_PhaseII_Q1_Unrelated20.L.pial.32k_fs_LR.surf.gii','L','METRIC','PFvbit3.func.gii');
%
% 23112016 RBM Updated doc
% Rogier B. Mars, University of Oxford, 30082013

specfilename = varargin{1};

metadata = ['<CaretSpecFile Version="1.0"><MetaData><MD><Name><![CDATA[UniqueID]]></Name><Value><![CDATA[{d475d6aa-960a-487c-9068-6b48ed2d9e01}]]></Value></MD></MetaData>'];
closingdata = [' </CaretSpecFile>'];

%=============================================
% Get files
%=============================================

filestuff = [];
for i = 2:3:nargin
   
   switch varargin{i}
       case 'L'
           filestuff = [filestuff ' <DataFile Structure="CortexLeft"'];
       case 'R'
           filestuff = [filestuff ' <DataFile Structure="CortexRight"'];
   end
   
   switch varargin{i+1}
       case 'SURFACE'
           filestuff = [filestuff ' DataFileType="SURFACE" Selected="true"> '];
       case 'METRIC'
           filestuff = [filestuff ' DataFileType="METRIC" Selected="true"> '];
       case 'VOLUME'
           filestuff = [filestuff ' DataFileType="VOLUME" Selected="true"> '];
   end
   
   filestuff = [filestuff varargin{i+2} ' </DataFile> '];
   
end

%=============================================
% Combine and save spec file
%=============================================

spec = [metadata filestuff closingdata];

fileID = fopen(specfilename,'w');
fprintf(fileID,spec);
fclose(fileID);