function rsn_fixOutlier(fnameIn,fnameOut,outlierFile,fnameErr,n,interpMethod)
% rsn_fixOutlier
% fixes outlier volumes by interpolation. If the source of outlying values
% is limited to a few slices, only those slices are interpolated.
%
% fnameIn:      path to input image (nX x nY x nZ x nTim)
% fnameOut:     path to the output image
% outlierFile:  path to Nx1 ascii text file
% fnameErr:     path to the sMAPE image (only used to fix outliers)
% n:            number of consequitive outliers to allow to be interpolated
% interpMethod: interpolation method
%                 'linear' (default), 'nearest', 'pchip', 'cubic', 'spline'
%--------------------------------------------------------------------------
%
% version history
% 2018-04-30    Lennart created
%
%--------------------------------------------------------------------------

% TODO: compare image to capture slices

% overhead
if nargin < 6 || isempty(interpMethod), interpMethod = 'linear'; end
if nargin < 5 || isempty(n), n = 2; end
if isempty(fnameOut), fnameOut = fnameIn; end


%==================================================
% Load data
%==================================================
fprintf('loading data\n');

% load data timeseries
[y, ~, hdr] = readimgfile(fnameIn);

% get the data dimensions
dims = size(y);
nX = dims(1);
nY = dims(2);
nInPlane = nX*nY;
nSlices = dims(3);
nVox = nX*nY*nSlices;
nTim = dims(4);

% load outlier file
idx = load(outlierFile)>0;
idxOutlier = find(idx);


%==================================================
% Fix outliers
%==================================================
while any(idx)
  
  % find onsets and offsets of continuous outliers
  idxOn = find(diff([0; idx])>0);
  idxOff = find(diff([idx; 0])<0);
  idx = [idxOn idxOff];

  % ignore onsets at the edges of the timeseries
  idx = idx( idx(:,1)>1 & idx(:,2) < nTim , :);

  % stop if no outliers remain
  if isempty(idx), break; end

  % keep only series of outliers that are < n long
  nConseqOutlier = diff(idx,[],2)+1;
  idx = idx( nConseqOutlier <= n , :);

  % stop if no outliers remain
  if isempty(idx), break; end

  % load error image
  fprintf('loading error image\n');
  [yErr, ~, ~] = readimgfile(fnameErr);

  % loop over outliers
  nOutlier = size(idx,1);
  m = 10*n;
  for c = 1:nOutlier

    % select a window to interpolate
    idxOn = max(1,idx(c,1)-m);
    idxOff = min(nTim,idx(c,2)+m);
    win = setdiff(idxOn:idxOff,idxOutlier);
    nWin = numel(win);
    
    % number of consequitive outliers
    winOutlier = idx(c,1):idx(c,2);
    nConseqOutlier = idx(c,2)-idx(c,1)+1;
    fprintf('fixing outlier volume:  %s\n',num2str(winOutlier))

    % find the mean error per slice in the context
    yErrContext = reshape(yErr(:,:,:,win),nInPlane,nSlices,nWin);
    yErrContext(yErrContext==0) = NaN;
    yErrContext = reshape(nanmean(yErrContext,1),nSlices,nWin);
    yErrContextMean = mean(yErrContext,2);
    yErrContextStd = std(yErrContext,0,2);
    
    % find the mean error per slice in the outlier
    yErrOutlier = reshape(yErr(:,:,:,winOutlier),nInPlane,nSlices,nConseqOutlier);
    yErrOutlier(yErrOutlier==0) = NaN;
    yErrOutlier = reshape(nanmean(yErrOutlier,1),nSlices,nConseqOutlier);
    yErrOutlier(yErrOutlier<=0) = NaN;
    
    % test whether the outlying values are found over the whole volume or
    % in a few slices
    nStd = 6;
    yErrOutlier = (bsxfun(@minus,yErrOutlier,yErrContextMean) ./ yErrContextStd) > nStd;
    sliceOutlier = sum(yErrOutlier,1) > 0 & sum(yErrOutlier,1) < 5;
    
    % interpolate either per volume or per slice
    if ~any(sliceOutlier)
      fprintf('  interpolating whole volume\n')
      
      % interpolate the whole volume if single slices cannot be identified
      v = reshape(y(:,:,:,win),nVox,nWin);
      t = win;
      tq = sort([win winOutlier]);
      vq = interp1(t,v',tq,interpMethod)';
      vq = vq(:,ismember(tq,winOutlier));
      
      % place the interpolated data back in the full data matrix
      y(:,:,:,winOutlier) = reshape(vq,nX,nY,nSlices,nConseqOutlier);
      
    else
      fprintf('  interpolating affected slices\n')
      
      % mark all good slices with 1's, all bad with 0's
      yErrOutlier = bsxfun(@times,~yErrOutlier,sliceOutlier);
      
      % loop over slices
      for s = find(any(yErrOutlier==0,2))'
        
        % identify good and bad slices from the outlier window
        winOutlierGood = winOutlier(yErrOutlier(s,:)==1);
        winOutlierBad = winOutlier(yErrOutlier(s,:)==0);
        
        % interpolate the whole volume if single slices cannot be identified
        t = sort([win winOutlierGood]);
        v = reshape(y(:,:,s,t),nInPlane,numel(t));
        tq = sort([t winOutlierBad]);
        vq = interp1(t,v',tq,interpMethod)';
        vq = vq(:,ismember(tq,winOutlierBad));
        
        % place the interpolated data back in the full data matrix
        y(:,:,s,winOutlierBad) = reshape(vq,nX,nY,1,numel(winOutlierBad));
        
      end
      
    end
    

  end
  
  % stop the while loop
  break
  
end

% return early if there is nothing to save  
if ~any(idx(:)) && strcmp(fnameIn,fnameOut), return; end


%==================================================
% Reshape and save
%==================================================
fprintf('saving fixed data\n');

% place data back into original format (overwrite the input hdr.vol)
hdr.vol = y;

% save the filtered image
save_nifti(hdr,fnameOut);
