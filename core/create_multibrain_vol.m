function create_multibrain_vol(outputfilename,varargin)
% function create_multibrain_vol(outputfilename,varargin)
%--------------------------------------------------------------------------
% Use
%   create_multibrain_vol('multibrain.nii.gz','/usr/local/fsl/data/standard/MNI152_T1_1mm_brain.nii.gz','/Users/rmars/code/MrCat-dev/data/chimpanzee/Chimplate/ChimpYerkes29_AverageT1w_restore_brain.nii.gz')
%
% version history
% 21-11-2018  Rogier    created
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2015-2018
%--------------------------------------------------------------------------

% outputfilename='test.nii.gz';
% species{1} = readimgfile('/usr/local/fsl/data/standard/MNI152_T1_1mm_brain.nii.gz');
% species{2} = readimgfile(['/Users/rmars/code/MrCat-dev/data/chimpanzee/Chimplate/ChimpYerkes29_AverageT1w_restore_brain.nii.gz']);

if nargin>2
    for vargnr = 1:length(varargin)
        species{vargnr} = readimgfile(varargin{vargnr});
    end
end

% Normalize intensities of the images
for s = 1:length(species)
    species{s} = normalize0(species{s});
end

% Deterimine final image size
maxdims = [0 0 0]; sumdims = [0 0 0];
for s = 1:length(species)
    speciesdim = size(species{s});
    sumdims = sumdims + speciesdim;
    for dim = 1:3
        if speciesdim(dim)>maxdims(dim), maxdims(dim)=speciesdim(dim); end
    end
end

% Create empty data
data = zeros(maxdims(1),maxdims(2),sumdims(3)+(length(species)*5));

% Fill in data
for s = 1:length(species)
    
        % fprintf('Working on species %i...\n',s);
    
        speciesdim = size(species{s});
        if speciesdim(1)<maxdims(1), dim1_coord = [round((maxdims(1)-speciesdim(1))/2) (round((maxdims(1)-speciesdim(1))/2)+speciesdim(1)-1)];
        elseif speciesdim(1)==maxdims(1), dim1_coord = [1 maxdims(1)];
        end
        if speciesdim(2)<maxdims(2), dim2_coord = [round((maxdims(2)-speciesdim(2))/2) (round((maxdims(2)-speciesdim(2))/2)+speciesdim(2)-1)];
        elseif speciesdim(2)==maxdims(2), dim2_coord = [1 maxdims(2)];
        end
        if speciesdim(3)<maxdims(3), dim3_coord = [round((maxdims(3)-speciesdim(3))/2) (round((maxdims(3)-speciesdim(3))/2)+speciesdim(3)-1)];
        elseif speciesdim(3)==maxdims(3), dim3_coord = [1 maxdims(3)];
        end
        
        if s==1
            dim3_coord = dim3_coord + maxdims(3) + 5;
        end
        
        data(dim1_coord(1):dim1_coord(2),dim2_coord(1):dim2_coord(2),dim3_coord(1):dim3_coord(2)) = species{s};
        
        % display_volume(data)
        
end

% % Diplay results
% display_volume(data);

% Save result
saveimgfile(data,outputfilename,[1 1 1]);