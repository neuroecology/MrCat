% the root directory of the functional rfMRI data
rootDir = fullfile(filesep,'Volumes','rsfMRI','anaesthesia','proc');

% where to find the current session
funcDir = fullfile(rootDir,'amyg','MK6','MI02256','functional');

% use this snippet of code if only a single run is present
% sMAPE = load(fullfile(funcDir,'raw_mc_sMAPE_IQRscaled.txt'));
% %sMAPE = load(fullfile(funcDir,'raw_mc_sMAPE.txt'));
% figure(1); hold off;
% plot(sMAPE);

% use this snippet of code if multiple runs are present
for c = 1:3
  sMAPE = load(sprintf('%s%srun%d%sraw_run%d_mc_sMAPE_IQRscaled.txt',funcDir,filesep,c,filesep,c));
  %sMAPE = load(sprintf('%s%srun%d%sraw_run%d_mc_sMAPE.txt',funcDir,filesep,c,filesep,c));
  %sMAPE = load(sprintf('%s%srun%d%sraw_run%d_mc_sMAPE_exclDetrend.txt',funcDir,filesep,c,filesep,c));
  figure(c); hold off;
  plot(sMAPE)
end
