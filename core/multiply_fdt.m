function [data, varargout] = multiply_fdt(varargin)
% function [data, varargout] = multiply_fdt(varargin)
%
% Read in fdt_matrix2 and one or more fdt_paths and multiply
%--------------------------------------------------------------------------
%
% Use:
%   multiply_fdt_eco('fdt_matrix2','mymatrix2.dot','fdt_paths','tract1.nii.gz','mask','MNI152_2mm_brain_mask.nii.gz','outputbase','results');
%   multiply_fdt_eco('fdt_matrix2','mymatrix2.dot','fdt_paths','tract1.nii.gz','fdt_path2','tract2.nii.gz','mask','MNI152_2mm_brain_mask.nii.gz','outputname','results');
%
% Inputs (using parameter format):
%   'fdt_matrix2'   string containing fdt_matrix2 file
%   'fdt_paths'     string containing fdt_paths file, can be repeated
%   'mask'          string containing mask for fdt_paths
%   'outputname'    string containing output file, assuming .func.gii (if one tract),
%                   dtseries.nii, or .mat
%   'hemi'          'L','R', or 'LR', required if output is .func.gii or dtseries.nii
%   'normalise'     'yes' or 'no' (default)
%   'threshold'     enter value, note that if both normalise and threshold
%                   are used, threshold is applied after normalise
%   'eco'           run multiplication iteratively to reduce computational load
%                   'yes' or 'no' (default)
%
% Uses: readimgfile.m, saveimgfile.m
%
% version history
% 2018-11-22  Rogier  improved debugging info
% 2018-11-16  Rogier  added debugging info
% 2018-10-16  Rogier  changed internal var handling to kill normalise bug
% 2018-09-12  Rogier  made masking optional and added eco option
% 2018-08-29  Rogier  can deal with averaged and .dot fdt_matrix2
% 2018-06-13  Rogier  made normalisation and thresholding optional
% 2018-06-05  Rogier  added normalisation
% 2018-02-20	Rogier  created
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2018-02-20
%--------------------------------------------------------------------------

%==================================================
% Housekeeping
%==================================================

% Defaults
fdt_matrix2_file = [];
fdt_paths_files = []; n_fdt_paths = 0;
output_file = [];
mask_file = [];
hemi = [];
norm_flag = 'no';
thresh = [];
eco = 'no';

    for vargnr = 2:2:length(varargin)
        switch varargin{vargnr-1}
            case 'fdt_matrix2'
                fdt_matrix2_file = varargin{vargnr};
            case 'fdt_paths'
                n_fdt_paths = n_fdt_paths + 1;
                fdt_paths_files{n_fdt_paths} = varargin{vargnr};
            case 'mask'
                mask_file = varargin{vargnr};
            case 'outputname'
                output_file = varargin{vargnr};
            case 'hemi'
                hemi = varargin{vargnr};
            case 'normalise'
                norm_flag = varargin{vargnr};
            case 'threshold'
                thresh = varargin{vargnr};
            case 'eco'
                eco = varargin{vargnr};
        end
    end

if isempty(fdt_matrix2_file), error('Error in MrCat:multiply_fdt_eco: fdt_matrix2 file not specified!'); end
if isempty(fdt_paths_files), error('Error in MrCat:multiply_fdt_eco: fdt_paths file(s) not specified!'); end
% if isempty(mask_file), error('Error in MrCat:multiply_fdt_eco: mask file not specified!'); end
if isempty(output_file), error('Error in MrCat:multiply_fdt_eco: output file not specified!'); end

if strcontain(output_file,'.func.gii') || strcontain(output_file,'.dtseries.nii')
  if isempty(hemi)
    error('Error in MrCat:multiply: hemisphere not defined for output .func.gii or .dtseriies.nii!');
  end
end

%==================================================
% Load data
%==================================================

fprintf('MrCat:multiply_fdt: loading files...\n');

if ~isempty(mask_file)
   mask = readimgfile(mask_file);

   % debugging info
   fprintf('mask size is %i by %i by %i, resulting in %i datapoints, of which %i are non-zero\n',size(mask,1),size(mask,2),size(mask,3),size(mask,1)*size(mask,2)*size(mask,3),sum(find(mask(:)>0)));

   mask = mask(:);
elseif isempty(mask_file)
   fprintf('no mask selected\n');
end

for i = 1:n_fdt_paths
    data = readimgfile(fdt_paths_files{i});

    % debugging info
    if i==1, fprintf('fdt_paths size is %i by %i by %i, resulting in %i datapoints\n',size(data,1),size(data,2),size(data,3),size(data,1)*size(data,2)*size(data,3)); end

    data = data(:);
    if ~isempty(mask_file)
        data = data(~~mask);
    end
    fdt_paths(:,i) = data; clear data;
end

fdt_matrix2 = readimgfile(fdt_matrix2_file);
if isfield(fdt_matrix2,'avgmat')
    fdt_matrix2 = fdt_matrix2.avgmat; % Deal with averaged fdt_matrix2

    % debugging info
    fprintf('fdt_matrix2 is %i by %i\n',size(fdt_matrix2,1),size(fdt_matrix2,2));

end

fprintf('done\n');

%==================================================
% Multiply
%==================================================

fprintf('MrCat:multiply_fdt: performing multiplication...');
switch norm_flag
	case 'yes'
		fdt_paths = normalise(fdt_paths);
end

if ~isempty(thresh)
    fdt_paths = threshold(fdt_paths,thresh);
end

switch eco
    case 'no'

      switch norm_flag
    	case 'yes'
        	fdt_matrix2 = normalise(fdt_matrix2,2);
      end

      if ~isempty(thresh)
    	fdt_matrix2 = threshold(fdt_matrix2,thresh);
      end

      multiplication = fdt_matrix2*fdt_paths;

    case 'yes'

      n=1000;
      N=size(fdt_matrix2,1);
      for i = 1:n:N
        fprintf('.');
	subdata = fdt_matrix2(i:min(i+n-1,N),:);

	switch norm_flag
    	case 'yes'
        	subdata = normalise(subdata,2);
        end

	if ~isempty(thresh)
		subdata = threshold(subdata,thresh);
	end

        multiplication(i:min(i+n-1,N),:) = subdata*fdt_paths;
      end
end

fprintf('done\n');

%==================================================
% Save
%==================================================

fprintf('MrCat:multiply_fdt: saving results...\n');

saveimgfile(multiplication,output_file,hemi);

fprintf('done\n');
