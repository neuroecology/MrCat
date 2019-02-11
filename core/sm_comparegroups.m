function stats = sm_comparegroups(data1,data2,nperms,method,varargin)
% Compare two groups of spiders
%--------------------------------------------------------------------------
%
% Use
%   stats = sm_comparegroups(data1,data2,nperms,method,varargin)
%
% Input
%   data1       number_of_arms*number_of_subjects_group1 matrix of spiders
%   data2       number_of_arms*number_of_subjects_group2 matrix of spiders
%   nperms      number of permutations to perform
%               if set to Inf the null-distribution will comprise the full
%               set of possible permutations (up to 10^6). It is assumed
%               that for all distance measures the conditions are
%               interchangeable: dist(A,B) == dist(B,A);
%   method      'manhattan', 'cosine_similarity', 'mahalanobis', or
%               'mahalanobispaired'
%
% Optional (parameter-value pairs)
%   normalize   normalization method 'normalize0', 'none',
%               'normalize0_all' (normalize over the whole of the two
%               groups, default)
%
% Ouput
%   stats.
%       actual      statistic of the actual data
%       criterion   maximum value from which data is not significant
%       nperms      number of permutations used
%       p           p-value
%       permutedD   statistics resulting from all permutations
%       result      string indicating whether match with template was significant
%
% Dependency
%   manhattan.m
%   cosine_similarity.m
%
% version history
% 2018-05-12  Lennart   added (paired) mahalanobis distance
% 2018-05-12  Lennart   refactored code, speed-up, documentation
% 2016-10-30  Rogier    Fixed small bug in passing permutedD (thanks to
%                       Josh Balsters) and in handling perm_results.m
% 2016-05-10  Rogier    Results handling improved to use perm_results.m
% 2015-09-16	Lennart		documentation
% 2015-09-06  Rogier    Cleaned up for GitHub release
% 2015-08-12  Rogier    Added plottitle option
% 2015-04-28  Rogier    Added normalize0_all option and made default
% 2015-04-24  Rogier    Added varargin and normalize option
% 2015-01-04  Rogier    Added cosine similarity method
% 2014-12-30  Rogier    created
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2014-12-30
%--------------------------------------------------------------------------


%===============================
%% Housekeeping
%===============================

nObs1 = size(data1,1);
nObs2 = size(data2,1);
nMeas1 = size(data1,2);
nMeas2 = size(data2,2);

if nObs1~=nObs2, error('Error in MrCat:sm_comparegroups: Spiders are of different length!'); end

% Defaults
normalize = 'normalize0';

% Optional inputs
if nargin>4
  for vargnr = 2:2:length(varargin)
    switch varargin{vargnr-1}
      case 'normalize'
        normalize = varargin{vargnr};
    end
  end
end

% Log stuff
stats.log.normalize = normalize;


%===============================
%% Determine permutations
%===============================

fprintf('Determining permutations...\n');

% set the observed group identity
groupIdObs = [ones(1,nMeas1) 2*ones(1,nMeas2)];

% draw a random set of permutations or create the full set of possibilities
if isfinite(nperms)
  
  % initialise the permutations
  groupId = nan(1+nperms,nMeas1+nMeas2);
  
  % the first instance is the observed data
  groupId(1,:) = groupIdObs;
  
  % draw random permutations to populate the null distribution
  for p = 2:nperms+1
    groupId(p,:) = groupIdObs(randperm(nMeas1+nMeas2));
  end
  
else

  % It is assumed that for all distance measures the conditions are
  % interchangeable: dist(A,B) == dist(B,A);
  %
  % This is implemented in the following line:
  % nMeasSwap = floor(min(nMeas1,nMeas2)/2);
  %
  % If the distance is signed, please change this line to:
  % nMeasSwap = min(nMeas1,nMeas2);
 
  % determine the number of interchangeable measurements
  switch method
    case {'manhattan','cosine_similarity','mahalanobis','mahalanobispaired'}
      nMeasSwap = floor(min(nMeas1,nMeas2)/2);
    otherwise
      nMeasSwap = min(nMeas1,nMeas2);
  end
  
  % count how many permutations are possible
  nPerm = 0;
  for k = 1:nMeasSwap
    nPerm = nPerm + nchoosek(nMeas1,k) * nchoosek(nMeas2,k);
  end
  
  % refuse to execute impractical number of permutations
  if nPerm > 10^6, error('Error in MrCat:sm_comparegroups: Exhaustive permutation sets are not practical beyond 10^6 permutations.'); end
  
  % pre-allocate group IDs (the first row has the observed group ID)
  groupId1 = ones(nPerm+1,nMeas1);
  groupId2 = 2*ones(nPerm+1,nMeas2);
  
  % loop over all possible combinations
  c = 1;
  for k = 1:nMeasSwap
    
    % retreive all possible k-draws from groups A and B
    subset1 = nchoosek(1:nMeas1,k);
    subset2 = nchoosek(1:nMeas2,k);
    
    for a = 1:size(subset1,1)
      
      for b = 1:size(subset2,1)
        
        % increment counter
        c = c + 1;
        
        % assign group permutations
        groupId1(c,subset1(a,:)) = 2;
        groupId2(c,subset2(b,:)) = 1;
        
      end
      
    end
    
  end
  
  % combine the two sets of group permutations
  groupId = [groupId1 groupId2];
  
end

% update the number of permutations
nperms = size(groupId,1);


%===============================
%% Perform permutations
%===============================

fprintf('Calculating the test statistic for each random draw...\n');

% aggregate the data
data = [data1 data2];

% loop over permutations
D = nan(1,nperms);
for p = 1:nperms
  
  % get mean statistic of permuted effect
  mu1 = mean(data(:,groupId(p,:)==1),2);
  mu2 = mean(data(:,groupId(p,:)==2),2);
  
  % normalize if requested
  switch normalize
    case 'normalize0'
      mu1 = normalize0(mu1);
      mu2 = normalize0(mu2);
    case 'normalize0_all'
      spider_data = normalize0([mu1; mu2]);
      mu1 = spider_data(1:nObs1);
      mu2 = spider_data(nObs1+1:end);
  end
  
  % calculate distance metric
  switch method
    case 'manhattan'
      D(p) = manhattan(mu1,mu2);
    case 'cosine_similarity'
      D(p) = cosine_similarity(mu1,mu2);
    case 'mahalanobis'
      D(p) = mahalanobis(mu1',mu2');
    case 'mahalanobispaired'
      d = abs(mu1-mu2)';
      D(p) = mahalanobis(d,d*0);
  end
  
end

% populate the output structure
stats.nperms = nperms-1; % don't count the observed data
stats.actual = D(1);
stats.permutedD = D;


%===============================
%% Determine criterion and report (this section needs tidying up)
%===============================

fprintf('Evaluating results...\n');

% retrieve the p-value, criterion, and plot a histogram
switch method
  case 'cosine_similarity'
    [pvalue,results] = perm_results(D,'side','left-side','toplot','yes');
  otherwise
    [pvalue,results] = perm_results(D,'side','right-side','toplot','yes');
end

% populate the output structure
stats.pvalue = pvalue;
stats.results = results;

fprintf('Done!\n');


%===============================
%% sub functions
%===============================

%--------------------------------------------------------------------------
function output = normalize0(input)
% As normalize1.m, but returning vector normalized between 0 and 1 instead
% of between -1 and 1.
%--------------------------------------------------------------------------
% version history
% 2015-09-16	Lennart		documentation
% 2013-03-28  Rogier    Adapted to suit both 2D and 3D matrices
% 2013-01-31  Rogier    created
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2013-01-31
%--------------------------------------------------------------------------

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
