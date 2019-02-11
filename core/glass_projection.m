function glass_projection(data,glass,varargin)
% Produce SPM-like glass brain projection. Assumes the glass brain and the
% data are in the same space. Data will be normalized using normalize0.
% Note that when images are FSL .nii.gz images read in using read_avw, this
% function will display results in radiological convention
%--------------------------------------------------------------------------
%
% Use
%   glass_projection(data,glass)
%   glass_projection(data,glass,varargin)
%
% Input
%   data        3D matrix
%   glass       3D matrix containing brain to be used for creating glass brain
%
% Optional (parameter-value pairs)
%   extraplot   produce extra plots, options: 'brain'
%   orientation 'data' (default) or 'flipx'
%   ROI         cut out region of interest in datapoints [xmin xmax ymin ymax zmin zmax]
%   toplot      string with plot name (without extension)
%   save_data   save projection as .mat file containing cell with x, y, and
%               z intensity projections without brain outline. Input is string
%               of filename without extension. Note that flip argument will
%               not be applied to this output!
%   colormap    colormap to use (default: gray), use flipud(gray) for white
%               background and gray colors
%
% Output
%   none        results are reported in a figure or saved to disk
%
% version history
% 2018-01-13  Rogier    Made flipx orientation 2*2 format and removed
%                       sagittal flip
% 2017-01-04  Rogier    Added colormap option
% 2015-11-05  Rogier    Added option to save .mat output
% 2015-09-16	Lennart		documentation
% 2015-08-27  Rogier    Cleaned up for GitHub release
% 2015-08-27  Rogier    Added normalize0 as subfunction
% 2015-03-06  Rogier    Changed combining glass and data to improve glass scaling
% 2014-10-27  Rogier    Added scaling of glass outline to maximum value of data
% 2014-06-30  Rogier    Added option to flipx (switch radiological/neurological)
% 2014-06-19  Rogier    Added option to save plot to disk
% 2014-06-16  Rogier    Added varargin ability to plot brain itself and ROI
% 2014-06-13  Rogier    Added ability to handle empty data
% 2014-03-11  Rogier    Added table output and corrected figure axes orientation
% 2013-03-28  Rogier    Completed using normalize0
% 2013-01-18  Rogier    created
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2013-01-18
%--------------------------------------------------------------------------


%===============================
%% Housekeeping
%===============================

if ~isempty(data) && ~isequal(size(data),size(glass)), error('Error: inputs not of the same size!'); end

extraplots = {};
orientation = 'data';
ROI = [];
toplot = [];
save_data = [];
colmap = gray;

% Optional inputs
if nargin>2
    for vargnr = 2:2:length(varargin)
        switch varargin{vargnr-1}
            case 'extraplot'
                extraplots{length(extraplots)+1} = varargin{vargnr};
            case 'orientation'
                orientation = varargin{vargnr};
            case 'ROI'
                ROI = varargin{vargnr};
            case 'toplot'
                toplot = varargin{vargnr};
            case 'save_data'
                save_data = varargin{vargnr};
            case 'colormap'
                colmap = varargin{vargnr};
        end
    end
end

%===============================
%% Prepare glass
%===============================

% Cut out ROI (if required)
if ~isempty(ROI), glass = glass(ROI(1):ROI(2),ROI(3):ROI(4),ROI(5):ROI(6)); end

orig_glass = glass;
glass = binarize(glass,0,'discard');

% Saggital
glass_sag = max(glass,[],1);
glass_sag = reshape(glass_sag,size(glass_sag,2),size(glass_sag,3));
glass_sag = rot90(glass_sag);
glass_sag = edge(glass_sag);

% Coronal
glass_cor = max(glass,[],2);
glass_cor = reshape(glass_cor,size(glass_cor,1),size(glass_cor,3));
glass_cor = rot90(glass_cor);
glass_cor = edge(glass_cor);

% Axial
glass_axial = max(glass,[],3);
glass_axial = rot90(glass_axial);
glass_axial = edge(glass_axial);

% % Check glass
% %-----------------------------
%
% figure;
% subplot(2,2,2); imagesc(glass_sag); title('Saggital');
% subplot(2,2,1); imagesc(glass_cor); title('Coronal');
% subplot(2,2,3); imagesc(glass_axial); title('Axial');


%===============================
%% Prepare data
%===============================

if ~isempty(data)
    
    % Cut out ROI (if required)
    if ~isempty(ROI), data = data(ROI(1):ROI(2),ROI(3):ROI(4),ROI(5):ROI(6)); end
    
    % Saggital
    data_sag = max(data,[],1);
    data_sag = reshape(data_sag,size(data_sag,2),size(data_sag,3));
    data_sag = rot90(data_sag);
    
    % Coronal
    data_cor = max(data,[],2);
    data_cor = reshape(data_cor,size(data_cor,1),size(data_cor,3));
    data_cor = rot90(data_cor);
    
    % Axial
    data_axial = max(data,[],3);
    data_axial = rot90(data_axial);
    
end

% Save data to disk (if required)
if ~isempty(save_data)
    projection{1} = data_cor;
    projection{2} = data_sag;
    projection{3} = data_axial;
    save([save_data '.mat'],'projection','-v7.3');
end

%===============================
%% Combine and display
%===============================

figure; colormap(colmap);

% Scale glass outline to maximum value of the data
maxdatavalue = max(data(:));

if ~isempty(data)
    
    % Saggital
    img = data_sag;
    img(find(glass_sag)) = maxdatavalue;
    switch orientation
        case 'data'
            subplot(2,2,2); imagesc(flipud(img)); title('Saggital'); set(gca,'YDir','normal');
        case 'flipx'
            subplot(2,2,2); imagesc((flipud(img))); title('Saggital'); set(gca,'YDir','normal');
    end
    
    % Coronal
    img = data_cor;
    img(find(glass_cor)) = maxdatavalue;
    switch orientation
        case 'data'
            subplot(2,2,1); imagesc(flipud(img)); title('Coronal'); set(gca,'YDir','normal');
        case 'flipx'
            subplot(2,2,1); imagesc(fliplr(flipud(img))); title('Coronal'); set(gca,'YDir','normal');
    end
    
    % Axial
    img = data_axial;
    img(find(glass_axial)) = maxdatavalue;
    switch orientation
        case 'data'
            subplot(2,2,3); imagesc(flipud(img)); title('Axial'); set(gca,'YDir','normal');
        case 'flipx'
            subplot(2,2,3); imagesc(fliplr(flipud(img))); title('Axial'); set(gca,'YDir','normal');
    end
    
elseif isempty(data)
    
    % Saggital
    switch orientation
        case 'data'
            subplot(2,2,2); imagesc(flipud(glass_sag)); title('Saggital'); set(gca,'YDir','normal');
        case 'flipx'
            subplot(2,2,2); imagesc((flipud(glass_sag))); title('Saggital'); set(gca,'YDir','normal');
    end
    
    % Coronal
    switch orientation
        case 'data'
            subplot(2,2,1); imagesc(flipud(glass_cor)); title('Coronal'); set(gca,'YDir','normal');
        case 'flipx'
            subplot(2,2,1); imagesc(fliplr(flipud(glass_cor))); title('Coronal'); set(gca,'YDir','normal');
    end
    
    % Axial
    switch orientation
        case 'data'
            subplot(2,2,3); imagesc(flipud(glass_axial)); title('Axial'); set(gca,'YDir','normal');
        case 'flipx'
            subplot(2,2,3); imagesc(fliplr(flipud(glass_axial))); title('Axial'); set(gca,'YDir','normal');
    end
    
end

% Save figure to disk (if required)
if ~isempty(toplot)
    saveas(gcf, toplot, 'png' );
end


%===============================
%% Create table
%===============================

if ~isempty(data)
    
    data = binarize(normalize0(data));
    bw = bwconncomp(data);
    
    % Collect cluster sizes
    clustsizes = [];
    for c = 1:bw.NumObjects
        clustsizes = [clustsizes; [c length(bw.PixelIdxList{c})]];
    end
    clustsizes = sortrows(clustsizes,-2);
    
    fprintf('Glass brain projection clusters (by size):\n');
    fprintf('Clust_ID\tClust_loc\tClust_size\n');
    fprintf('==========================================\n');
    for c = 1:bw.NumObjects
        data = zeros(size(data)); data(bw.PixelIdxList{c}(ceil(length(bw.PixelIdxList{c})/2)))=1;
        [i,j,k] = ind2sub(size(data),find(data==1));
        fprintf('%i\t\t%i %i %i\t%i\n',clustsizes(c,1),i,j,k,clustsizes(c,2));
    end
    
end


%===============================
%% Optional additional plotting
%===============================

if ~isempty(extraplots)
    
    figure; colormap(gray);
    
    % Saggital
    glass_sag = mean(orig_glass,1);
    glass_sag = reshape(glass_sag,size(glass_sag,2),size(glass_sag,3));
    glass_sag = normalize1(rot90(glass_sag));
    
    % Coronal
    glass_cor = mean(orig_glass,2);
    glass_cor = reshape(glass_cor,size(glass_cor,1),size(glass_cor,3));
    glass_cor = normalize1(rot90(glass_cor));
    
    % Axial
    glass_axial = mean(orig_glass,3);
    glass_axial = normalize1(rot90(glass_axial));
    
    % Saggital
    subplot(2,2,2); imagesc(flipud(glass_sag)); title('Saggital'); set(gca,'YDir','normal');
    
    % Coronal
    subplot(2,2,1); imagesc(flipud(glass_cor)); title('Coronal'); set(gca,'YDir','normal');
    
    % Axial
    subplot(2,2,3); imagesc(flipud(glass_axial)); title('Axial'); set(gca,'YDir','normal');
    
end


%===============================
%% sub functions
%===============================

function output = normalize0(input)
% function output = normalize0(input)

% As normalize1.m, but returning vector normalized between 0 and 1 instead
% of between -1 and 1.
%
% Rogier B. Mars, University of Oxford, 31012013
% 28032013 RBM Adapted to suit both 2D and 3D matrices

orig_size = size(input);

input = input(:);
output = ((input-min(input))./(max(input)-min(input)));

% Reshape back to input format
if length(orig_size)==2
    output = reshape(output,orig_size(1),orig_size(2));
elseif length(orig_size)==3
    output = reshape(output,orig_size(1),orig_size(2),orig_size(3));
else
    error('Input matrices of this size are currenlty not supported!');
end
