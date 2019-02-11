function [] = hcp_create_func_gii(data,outbase,hemi)
% function hcp_create_func_gii(data,outbase,hemi)
%
% Inputs:
%   data    data vector (not in data.cdata format)
%   outbase string without extension
%   hemi    'L' or 'R'
%
% Saad's original create_func_gii.m, his documentation below:
%
% ==============================================
% [] = create_dconn(data,outbase,hemi)
% hemi='L' or 'R'
%
% S Jbabdi 01/13
% % ==============================================
%
% 08082014


addpath /Users/rogiermars/matlab_toolboxes/CIFTIMatlabReaderWriter_old

gii=gifti(['/Users/rogiermars/matlab_toolboxes/CIFTIMatlabReaderWriter_old/' hemi '.func.gii']);

for i=(length(gii.private.data)+1):size(data,2)
    gii.private.data{i}=gii.private.data{1};
end

for i=1:size(data,2)
    gii.private.data{i}.data=single(data(:,i));
    gii.private.data{i}.attributes.Intent='NIFTI_INTENT_NONE';

end

N=size(gii.cdata,1);
str=gii.private.data{1}.metadata(1).value;
str=strrep(str,num2str(N),num2str(size(gii.cdata,1)));
gii.private.data{1}.metadata(1).value=str;
gii.private.data{1}.attributes.Dim=N;

%gii.cdata=data;
% if(~strcmp(outbase(end-8:end),'.func.gii'))
    outbase=[outbase '.func.gii'];
% end
save(gii,outbase);

%   
% %%%%%%
%     
%    cmd='/Applications/workbench/macosx64_apps/wb_command.app/Contents/MacOS/wb_command' 
%    
%    if(size(X,2) < size(cifti.cdata,2))
%        error('template cifti has more columns than data, abort')
%    end
% for i=(length(cifti.private.data)+1):size(X,2)
%     cifti.private.data{i}=cifti.private.data{1};
% end
% 
% for i=1:size(X,2)
%     cifti.private.data{i}.data=single(X(:,i));
%     cifti.private.data{i}.attributes.Intent='NIFTI_INTENT_NONE';
% 
% end
% save(cifti,filename);
% 
% %N=size(cifti.cdata,1);
% %ciftisave(cifti,filename,cmd,N);%
% %save(cifti,[filename '.gii'],'GZipBase64Binary')




end