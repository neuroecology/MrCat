function [cifti, data] = cifti_open( cifti_file, wb_cmd )
% function data = cifti_open(filename,wb_command)
%
% Open a CIFTI file by converting to GIFTI external binary first and then
% using the GIFTI toolbox. Based on Saad Jbabdi's original
%--------------------------------------------------------------------------
%
% Use:
%   data = cifti_open('myfile.dconn.nii');
%   data = cifti_open('yourfile','/Applications/workbench/bin_macosx64/wb_command');
%
% Uses: gifti toolbox
%
% Obligatory input:
%   filename    string containing name of CIFTI file to read in (incl
%               extension)
%
% Optional input:
%   wb_command  string containing link to wb_command version to be used
%
% version history
%   2018-06-13  Rogier  fixed header bug
%   2018-06-12  Rogier  created based on Saad Jbabdi's original
%
% copyright
%   Rogier B. Mars
%   University of Oxford & Donders Institute, 2018
%--------------------------------------------------------------------------

    disp(['[cifti_open] Opening file "' cifti_file '"...']); 
    
    % Create temporary file to convert to a GIFTI file
    gifti_file = [tempname '.gii'];
    
    % Convert CIFTI to GIFTI using WorkBench
    if nargin < 2 || isempty(wb_cmd), wb_cmd = 'wb_command'; end
    [status,~] = unix(sprintf( '%s -cifti-convert -to-gifti-ext "%s" "%s"', wb_cmd, cifti_file, gifti_file ));
    assert( status == 0, 'Could not convert CIFTI file to temporary GIFTI.' );

    % Open converted GIFTI file
    cifti = gifti(gifti_file);
    
    % Extract index data
    if nargout > 1
        data = parse_xml_metadata( cifti.private.data{1}.metadata.value, cifti.cdata );
    end

    % Delete temporary GIFTI files
    unix(['rm ' gifti_file ' ' gifti_file '.data']);

end

function BM = parse_xml_metadata( str, data )

    % parse XML string
    tree = xmltree(str);

    % register tree elements which correspond either to:
    %  - a brain model
    %  - a space/index transformation
    bmi = [];
    IJK2XYZi = [];
    XYZ2IJKi = [];

    for t=1:length(tree)
        try NAME=get(tree,t,'name'); catch, NAME=''; end
        switch NAME
            case 'BrainModel'
                bmi = [bmi t];
            case 'TransformationMatrixVoxelIndicesIJKtoXYZ'
                IJK2XYZi = [IJK2XYZi t];
            case 'TransformationMatrixVoxelIndicesXYZtoIJK'
                XYZ2IJKi = [XYZ2IJKi t];
        end
    end
    if numel(IJK2XYZi)>=2 || numel(XYZ2IJKi)>=2
        error('Too many transformation matrices found.');
    end

    % parse brain model
    BM = cell(numel(bmi),1);
    for b=1:numel(bmi)

        attr=get(tree,bmi(b),'attributes');
        for a=1:length(attr)
            KEY=attr{a}.key;
            VAL=attr{a}.val;
            BM{b}.(KEY) = VAL;
        end

        try cont=get(tree,bmi(b),'contents'); catch, cont=[]; end
        while ~isempty(cont)

            cur = cont(1);
            try ncont=get(tree,cur,'contents'); catch, ncont=[]; end
            cont = union(cont(2:end),ncont);
            
            if strcmp(get(tree,cur,'type'),'element') && ~isempty(ncont) && strcmp(get(tree,ncont,'type'),'chardata')
            switch get(tree,cur,'name')

                case 'VertexIndices'

                    didx   = 1 + str2num(get(tree,ncont,'value'));
                    icount = str2num(BM{b}.IndexCount);
                    ioff   = str2num(BM{b}.IndexOffset);
                    midx   = (ioff+1) : (ioff+icount);

                    if numel(didx) ~= icount
                        error('Data dimension does not agree with index count!')
                    end
                    BM{b}.SurfaceIndices = didx;
                    BM{b}.DataIndices    = midx;
                    BM{b}.Data           = data(midx,:);

                case 'VoxelIndicesIJK'

                    didx   = 1 + str2num(get(tree,ncont,'value'));
                    icount = str2num(BM{b}.IndexCount);
                    ioff   = str2num(BM{b}.IndexOffset);
                    midx   = (ioff+1) : (ioff+icount);

                    if numel(didx)/3 == icount
                        didx=reshape(didx,[3,numel(didx)/3])';
                    else
                        error('Data dimension does not agree with index count!')
                    end
                    BM{b}.VolumeIndicesIJK = didx;
                    BM{b}.DataIndices      = midx;
                    BM{b}.Data             = data(midx,:);

                    if ~isempty(IJK2XYZi)
                        XT=struct;
                        iattr=get(tree,IJK2XYZi,'attributes');
                        for a=1:length(iattr)
                            KEY=iattr{a}.key;
                            VAL=iattr{a}.val;
                            XT.(KEY) = VAL;
                        end
                        icont=get(tree,IJK2XYZi,'contents');
                        for c=1:length(icont);
                            if strcmp(get(tree,icont(c),'type'),'chardata')
                                trx=reshape(str2num(get(tree,icont(c),'value')),[4 4]);
                            end
                        end
                        XT.TransformMatrix = trx;
                        BM{b}.IJK2XYZ = XT;
                    end

                case 'VoxelIndicesXYZ'

                    didx   = 1 + str2num(get(tree,ncont,'value'));
                    icount = str2num(BM{b}.IndexCount);
                    ioff   = str2num(BM{b}.IndexOffset);
                    midx   = (ioff+1) : (ioff+icount);

                    if numel(didx)/3 == icount
                        didx=reshape(didx,[3,numel(didx)/3])';
                    else
                        error('Data dimension does not agree with index count!')
                    end
                    BM{b}.VolumeIndicesXYZ = didx;
                    BM{b}.DataIndices      = midx;
                    BM{b}.Data             = data(midx,:);

                    if ~isempty(XYZ2IJKi)
                        XT=struct;
                        xattr=get(tree,XYZ2IJKi,'attributes');
                        for a=1:length(xattr)
                            KEY=xattr{a}.key;
                            VAL=xattr{a}.val;
                            XT.(KEY) = VAL;
                        end
                        xcont=get(tree,XYZ2IJKi,'contents');
                        for c=1:length(xcont);
                            if strcmp(get(tree,xcont(c),'type'),'chardata')
                                trx=reshape(str2num(get(tree,xcont(c),'value')),[4 4]);
                            end
                        end
                        XT.TransformMatrix = trx;
                        BM{b}.XYZ2IJK = XT;
                    end

            end
            end
        end
    end

end
