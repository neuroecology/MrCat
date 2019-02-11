function rsn_filter(fnameData,fnameOut,fnameMask,TR,nComp,fFilt,hpType,lpType,filtOrder,wb_command,flgPlot)
% Detect high-frequency noise peaks likely to be related to the respiratory
% apparatus and apply band-stop filter (6th order butterworth) to suppress.
% Optional high-pass filtering using fslmaths -bptf, matlab butterworth or
% Fieldtrip windowed sync finite-impulse response.
%
% Example usage:
%   rsn_filter('func.nii.gz','func_hpfilt.nii.gz','func_brain_mask.nii.gz',[],3,[1/2000 -1],'fsl','none','hpbslp',true)
%
% REQUIRED
%   fnameData - input filename of the data image to be filtered
%   fnameOut  - output filename of the filtered data image
%
% OPTIONAL
%   fnameMask - filename of a (brain) mask matching the data. Taking all
%               the data if left empty
%   TR        - repetition time (TR) of the data. If not provided it will
%               be retrieved from the data header with an assumed GRAPPA
%               acceleration factor of 2
%   nComp     - number of principal components to detect the noise from.
%               Please note that the mean is always considered, so nComp=1
%               takes the mean and the first principal component after the
%               mean is subtracted from the data.
%   fFilt     - [high-pass low-pass] cut-off frequencies for the filter.
%               No filter will be applied if fFilt is empty, zero, or
%               negative. If one value is supplied this is interpreted as
%               a high-pass cutoff.
%   hpType    - specify the type of high-pass filter, if requested.
%               'fsl' (default), using fslmaths -bptf (1/fFilt)/(2*TR)
%               'but' using matlab butterworth high-pass filter
%               'ft'  using fieldtrip windowed sync FIR filter
%   lpType    - specify the type of low-pass filter, if requested.
%               'fsl' using fslmaths -bptf (1./fFilt)./(2*TR)
%               'but' (default), using matlab butterworth low-pass filter
%               'ft'  using fieldtrip butterworth low-pass filter
%   filtOrder - specify the order of the filters using hp/lp/bp/bs
%               default: 'hpbslp'
%   wb_command- path to wb_command to save dtseries cifti files
%   flgPlot   - boolean whether to plot the progress (default: false)
%
%
% (c) Lennart Verhagen, 2017-2018

% overhead
narginchk(2,11);
if nargin<11 || isempty(flgPlot), flgPlot = false; end
if nargin<10 || isempty(wb_command), wb_command = ''; end
if nargin<9 || isempty(filtOrder), filtOrder = 'hpbslp'; end
if nargin<8 || isempty(lpType), lpType = 'but'; end
if nargin<7 || isempty(hpType), hpType = 'fsl'; end
if nargin<6 || isempty(fFilt), fFilt = [-1 -1]; end
if nargin<5 || isempty(nComp), nComp = 3; end
if nargin<4, TR = []; end
if nargin<3, fnameMask = ''; end
if isempty(fnameOut), error('please provide a name for the output file <fnameOut>'); end
if isempty(fnameData), error('please provide an input image'); end

% ensure both a high-pass and low-pass frequency are specified
if numel(fFilt)==1, fFilt = [fFilt -1]; end
fFilt(fFilt==0) = -1;

% infer which filters to apply before and which after the band-stop filter
filtOrder = regexp(filtOrder,'bs','split');
if numel(filtOrder) == 1, filtOrder{2} = ''; end
flgSave = true; % by default the input data needs to be saved to the output

% dock all figures if plots are requested
if flgPlot
  set(0,'DefaultFigureWindowStyle','docked')
  hf = figure;
else
  hf = -1;
end

% read in data
fprintf('reading data: %s\n',fnameData);
mask = []; dtseries = []; hdr = [];
if ~isempty(regexp(fnameData,'\.dtseries\.nii$','match','once'))

  % check filter input
  if (fFilt(1)>0 && strcmpi(hpType,'fsl')) || (fFilt(2)>0 && strcmpi(lpType,'fsl'))
    error('the FSL filter cannot be used the dense timeseries cifti files');
  end

  % infer the location of wb_command
  if isempty(wb_command)
    % infer the location of wb_command from the .bash_profile
    [~,wb_command] = unix('cat ~/.bash_profile | grep "/workbench/" | head -1 | cut -d"=" -f2 | tr "\n" "/"');
    wb_command = fullfile(wb_command,'wb_command');
  end

  % read in dense time-series cifti file
  dtseries = ciftiopen(fnameData);
  data = double(dtseries.cdata);
  dims = size(data);
  nTim = dims(2);

  % apply the mask, if requested
  if ~isempty(fnameMask)
    % read in the mask/roi cifti file
    fprintf('reading mask: %s\n',fnameMask);
    mask = ciftiopen(fnameMask);
    mask = double(mask.cdata);
    % exclude voxels/vertices outside the mask
    data = data(mask>0,:);
  end

  % retrieve TR if not provided
  if isempty(TR)
    % TODO: I should actually retrieve the TR from the header...
    warning('TR not specified, assuming TR of 2 seconds');
    TR = 2;
  end

else

  % read in volumetric nifti file
  [data, ~, hdr] = readimgfile(fnameData);

  % restructure the data matrix
  dims = size(data);
  nVox = prod(dims(1:3));
  nTim = dims(4);
  data = reshape(data,nVox,nTim);

  % apply the mask, if requested
  if ~isempty(fnameMask)
    % read in the mask
    fprintf('reading mask: %s\n',fnameMask);
    mask = readimgfile(fnameMask);
    mask = reshape(mask,nVox,1);
    % exclude voxels outside the mask
    data = data(mask>0,:);
  end

  % retrieve TR if not provided
  if isempty(TR)
    accelFact = 2;
    warning('assuming acceleration factor of %d',accelFact);
    TR = hdr.pixdim(5)/(1000*accelFact);
    fprintf('TR: %1.5f\n',TR);
  end

end


% define length and sampling frequency of the timeseries
Fs = 1/TR;
% number of samples
L = nTim;
% specify frequencies of the spectrum
f = Fs*(0:floor(L/2))'/L;


%% apply the requested filters before the band-stop
if ~isempty(filtOrder{1}) && any(fFilt>0)

  % set only the appropriate filters
  fFiltPre = fFilt;
  if strcmpi(filtOrder{1},'hp')
    fprintf('high-pass filtering\n');
    fFiltPre(2) = -1;
  elseif strcmpi(filtOrder{1},'lp')
    fprintf('low-pass filtering\n');
    fFiltPre(1) = -1;
  else
    fprintf('band-pass filtering\n');
  end

  % apply requested filters
  [data,fFiltPre,flgSave] = hplpFilt(data,Fs,fFiltPre,hpType,lpType,hdr,dims,mask,flgSave,fnameOut);

  % set only the appropriate filters
  if strcmpi(filtOrder{1},'hp')
    fFilt(1) = fFiltPre(1);
  elseif strcmpi(filtOrder{1},'lp')
    fFilt(2) = fFiltPre(2);
  else
    fFilt = fFiltPre;
  end

  % plot the new signal in time and frequency domain, if requested
  if flgPlot, PlotComp(hf,data,nComp,f); end

end


%% detect high-frequency noise peaks in principal components and apply band-stop filtering
if nComp > 0 && ~isempty(regexp(filtOrder,'bs','match','once'))
  flgSave = true;

  % specify the minimum respiratory artefact frequency
  %FbsMin = 0.10;
  FbsMin = 0.07;

  % detect noise-peaks and apply band-stop filter accordingly
  [data, Flp] = bsFilt(data,nComp,Fs,FbsMin,f,flgPlot,hf);

  % if a lowpass butterworth filter is requested from the input
  % arguments, combine with a possible lowpass filter needed for
  % noise peaks
  if ~isempty(Flp)
    filtOrder{2} = [filtOrder{2} 'lp'];
    if fFilt(2) > 0
      fFilt(2) = min([Flp fFilt(2)]);
    else
      fFilt(2) = Flp;
    end
  end

  % plot the new signal in time and frequency domain, if requested
  if flgPlot, PlotComp(hf,data,nComp,f); end

end


%% apply the requested filters after the band-stop
if ~isempty(filtOrder{2}) && any(fFilt>0)

  % set only the appropriate filters
  fFiltPost = fFilt;
  if strcmpi(filtOrder{2},'hp')
    fprintf('high-pass filtering\n');
    fFiltPost(2) = -1;
  elseif strcmpi(filtOrder{2},'lp')
    fprintf('low-pass filtering\n');
    fFiltPost(1) = -1;
  else
    fprintf('band-pass filtering\n');
  end

  % apply requested filters
  [data,~,flgSave] = hplpFilt(data,Fs,fFiltPost,hpType,lpType,hdr,dims,mask,flgSave,fnameOut);

  % plot the new signal in time and frequency domain, if requested
  if flgPlot, PlotComp(hf,data,nComp,f); end

end


% save the data if not already done by FSL filtering
if flgSave
  fprintf('saving filtered image\n');

  % switch depending on data type
  if ~isempty(dtseries)

    % place data back into original format
    if ~isempty(fnameMask)
      dtseries.cdata = zeros(dims);
      dtseries.cdata(mask>0,:) = data;
    end
    % save the filtered dtseries cifti
    ciftisave(dtseries,fnameOut,size(data,1),wb_command)

  else

    % place data back into original format (overwrite the input hdr.vol)
    if ~isempty(fnameMask)
      hdr.vol = zeros(prod(dims(1:3)),dims(4));
      hdr.vol(mask>0,:) = data;
      hdr.vol = reshape(hdr.vol,dims);
    else
      hdr.vol = reshape(data,dims);
    end

    % save the filtered volumetric image
    save_nifti(hdr,fnameOut);

  end

end

% final report
fprintf('all done\n');



% --------- %
% FUNCTIONS
% --------- %

% HIGH_PASS / LOW-PASS FILTER
function [data,fFilt,flgSave] = hplpFilt(data,Fs,fFilt,hpType,lpType,hdr,dims,mask,flgSave,fnameOut)
% return quickly, if no filter is requested
if all(fFilt)<=0, return; end

% Nyquist frequency
Fn = Fs/2;

% first sort the high-pass and band-pass filtering
if fFilt(1)>0 && strcmpi(hpType,'but')
  % filter the data with a butterworth filter

  if fFilt(2)>0 && strcmpi(hpType,'but')
    [B, A] = butter(6, fFilt./Fn, 'bandpass');
    fFilt = [-1 -1]; % high- and low-pass are now done
  else
    [B, A] = butter(6, fFilt(1)./Fn, 'high');
    fFilt(1) = -1; % high-pass is now done
  end
  data = filtfilt(B, A, data')';
  flgSave = true;

elseif fFilt(1)>0 && strcmpi(hpType,'ft')
  % Fieldtrip provides a windowed sync FIR filter that has reduced
  % edge-effects. This is beneficial for rs-fMRI data where you would
  % like to keep the edges. However, I have not yet incorporated the
  % relevant code in MrCat, so if you don't have FieldTrip installed
  % you will have to do with the butterworth filter. Generally, I
  % would recommend to avoid using this filter, and opt for the
  % non-linear (high-pass) filter implemented in fslmaths.
  data = ft_preproc_highpassfilter(data, Fs, fFilt(1), [], 'firws');
  fFilt(1) = -1; % high-pass is now done
  flgSave = true;

end

% call FSL if it was requested to handle the low-pass and/or high-pass filter
if (fFilt(1)>0 && strcmpi(hpType,'fsl')) || (fFilt(2)>0 && strcmpi(lpType,'fsl'))
  fprintf('calling FSL to filter the timeseries\n');
  fprintf('this will take a while\n');

  % place data back into original format (overwrite the input hdr.vol)
  if ~isempty(mask)
    hdr.vol = zeros(prod(dims(1:3)),dims(4));
    hdr.vol(mask>0,:) = data;
    hdr.vol = reshape(hdr.vol,dims);
  else
    hdr.vol = reshape(data,dims);
  end

  % save the filtered image
  save_nifti(hdr,fnameOut);
  flgSave = false;

  % call FSL filter
  TR = 1/Fs;
  fFiltSigma = (1./fFilt)./(2*TR);
  if all(fFilt>0) && strcmpi(hpType,'fsl') && strcmpi(lpType,'fsl')
    cmd = sprintf('$FSLDIR/bin/fslmaths %s -bptf %.18f %.18f %s',fnameOut,fFiltSigma(1),fFiltSigma(2),fnameOut);
    fFilt = [-1 -1]; % high- and low-pass are now done
  elseif fFilt(1)>0 && strcmpi(hpType,'fsl')
    cmd = sprintf('$FSLDIR/bin/fslmaths %s -bptf %.18f -1 %s',fnameOut,fFiltSigma(1),fnameOut);
    fFilt(1) = -1; % high-pass is now done
  elseif fFilt(2)>0 && strcmpi(lpType,'fsl')
    cmd = sprintf('$FSLDIR/bin/fslmaths %s -bptf -1 %.18f %s',fnameOut,fFiltSigma(2),fnameOut);
    fFilt(2) = -1; % low-pass is now done
  end
  [status, output] = call_fsl(cmd);
  if status, error(output); end

  % read in filtered data and reshape
  data = readimgfile(fnameOut);
  data = reshape(data,prod(dims(1:3)),dims(4));

  % apply the mask, if requested
  if ~isempty(mask)
    data = data(mask>0,:);
  end

end

% now wrap up by sorting the low-pass filtering
if fFilt(2)>0 && strcmpi(lpType,'but')
  [B, A] = butter(6, fFilt(2)./Fn, 'low');
  data = filtfilt(B, A, data')';
  fFilt(2) = -1; % low-pass is now done
  flgSave = true;
elseif fFilt(2)>0 && strcmpi(lpType,'ft')
  data = ft_preproc_lowpassfilter(data, Fs, fFilt(2), 6, 'but');
  fFilt(2) = -1; % low-pass is now done
  flgSave = true;
end



% BAND-STOP FILTER
function [data, Flp] = bsFilt(data,nComp,Fs,FbsMin,f,flgPlot,hf)

% Nyquist frequency
Fn = Fs/2;

% Eigen decomposition giving mean and principal components
fprintf('extracting mean and components\n');
dataComp = rsn_decomp(data,nComp,'pca');

% loop over the components to process
fprintf('identifying noise frequency band(s)\n');
Fbs = cell(1,nComp);
for c = 1:nComp

  % transform to frequency domain
  P1 = freqspectrum(dataComp(:,c));

  % find high-power noise peaks
  Phf = P1(f>FbsMin);
  PhfMed = median(Phf);
  thr = PhfMed + 5 * (prctile(Phf,75)-PhfMed);
  Fbs{c} = f((f>FbsMin)&(P1>thr));

  % plot if requested
  if flgPlot
    % plot the signal
    figure(hf); subplot(nComp,2,((c-1)*2)+1); hold off;
    plot(dataComp(:,c),'g','LineWidth',0.25);

    % plot the spectrum
    figure(hf); subplot(nComp,2,((c-1)*2)+2); hold off;
    plot(f,P1,'g','LineWidth',0.25);
  end

end

% collect the identified noise frequencies
Fbs = unique(cat(1,Fbs{:}));

% add window and combine adjacent windows
win = 0.002;
Fbs = [Fbs-win Fbs+win];
for m = 1:(size(Fbs,1)-1)
  if Fbs(m,2) >= Fbs(m+1,1)
    Fbs(m+1,1) = Fbs(m,1);
    Fbs((Fbs(:,1) == Fbs(m,1)),2) = Fbs(m+1,2);
  end
end
Fbs = unique(Fbs,'rows');
Fbs(:,2) = min(Fbs(:,2),max(f));

% report if requested
if flgPlot
  disp('identified band-stop windows:');
  disp(Fbs);
end

% identify low-pass parts of the band-stop request (approaching the Nyquist freq)
idxFlp = Fbs(:,2) >= f(end-25);
Flp = min(Fbs(idxFlp,1));
Fbs = Fbs(~idxFlp,:);

% bandstop filter the noise peaks
fprintf('bandstop filtering of noise components\n');
for c = 1:size(Fbs,1)
  %data = ft_preproc_bandstopfilter(data, Fs, Fbs(c,:), 6, 'but');
  [B, A] = butter(6, Fbs(c,:)/Fn, 'stop');
  data = filtfilt(B, A, data')';
end



% spectral transform
function P1 = freqspectrum(S)
% fourier transform
Y = fft(S);
% reconstruct the single-sided frequency spectrum
L = numel(Y);
P2 = abs(Y/L);
P1 = P2(1:floor(L/2)+1);
P1(2:end-1) = 2*P1(2:end-1);



% plot time and frequency of components
function PlotComp(hf,data,nComp,f)
% Eigen decomposition giving mean and principal components
fprintf('extracting mean and components\n');
dataComp = rsn_decomp(data,nComp,'pca');

% loop over components
for c = 1:nComp

  % transform to frequency domain
  P1 = freqspectrum(dataComp(:,c));

  % plot the signal
  figure(hf); subplot(nComp,2,((c-1)*2)+1); hold on;
  plot(dataComp(:,c),'b','LineWidth',0.25);

  % plot the spectrum
  figure(hf); subplot(nComp,2,((c-1)*2)+2); hold on;
  plot(f,P1,'b','LineWidth',0.25);

end
