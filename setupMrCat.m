% get MrCat directory from the environment
MrCatDir = getenv('MRCATDIR');

% find MrCatDir based on the current script location
if isempty(MrCatDir)
  currDir = pwd;
  MrCatDir = fileparts(mfilename('fullpath'));
  cd(MrCatDir);
  MrCatDir = pwd;
  cd(currDir);
end

% add MrCat toolbox, but without the hidden .git folders
MrCatPath = genpath(MrCatDir);
MrCatPath = regexp(MrCatPath,':','split');
iNoHiddenFolder = cellfun(@(str) ~isempty(str) && isempty(regexp(str,'/\.','match','once')),MrCatPath);
MrCatPath = sprintf('%s:',MrCatPath{iNoHiddenFolder});
addpath(MrCatPath);
