function cog = surf_cog(sphere,data,roi,area)
% Find the (weighted) centre of gravity of a surface metric
%--------------------------------------------------------------------------
%
% Use
%   cog = surf_cog(sphere,metric,roi)
%
% Input
%   sphere  a spherical surface with vertices (.surf.gii file)
%   data    one of the following three options:
%             - metrics of surface vertices (.func.gii or .shape.gii file)
%             - label cifti file describing rois (.dlabel.nii)
%             - matrix of vertex indices (integer or .txt file), a centre
%               of gravity is calculated for each column independently.
% Optional
%   roi     one of the following two options:
%             - surface region-of-interest (.shape.gii file)
%             - boolean flag indicating if the output should be constrained
%               to the non-zero vertices in the metric file (true or false)
%   area    a metric surface area file matching the sphere (.shape.gii)
%             In the calculation of the centre-of-gravity each vertex is
%             weighted by its surface area. 
%
% Output
%   cog     centre of gravity of the surface metrics, reported as the
%             corresponding vertex index
%
% version history
% 2016-11-14  Lennart   added area weights
% 2016-11-10  Lennart   created
%
% copyright
% Lennart Verhagen & Rogier B. Mars
% University of Oxford & Donders Institute, 2016-11-10
%--------------------------------------------------------------------------


%% overhead
%------------------------------

% read in surface gifti
sphere = gifti(sphere);

% process or read in the metric specification
if ischar(data)
  if ~isempty(regexp(data,'\.label\.gii$','once'))
    % support label files
    data = gifti(data);
    nDatasets = size(data.cdata,2);
    if nDatasets > 1, error('label files with multiple sub-volumes are not (yet) supported'); end
    % seperate the labels into seprate cells
    labels = unique(data.cdata(data.cdata>0));
    nDatasets = length(labels);
    idx = cell(1,nDatasets); val = cell(1,nDatasets);
    for c = 1:nDatasets
      idx{c} = find(data.cdata == labels(c));
      val{c} = ones(size(idx{c}));
    end
  elseif ~isempty(regexp(data,'\.(func|shape)\.gii$','once'))
    % support metric files
    data = gifti(data);
    % allow multiple sub-volumes
    nDatasets = size(data.cdata,2);
    idx = cell(1,nDatasets); val = cell(1,nDatasets);
    for c = 1:nDatasets
      idx{c} = data.cdata(:,c) > 0;
      val{c} = data.cdata(idx{c},:);
      idx{c} = find(idx{c});
    end
  else
    idx = dlmread(data);
    val = ones(size(idx));
  end
else
  idx = data;
  val = ones(size(idx));
end
% support multiple columns
if ~iscell(idx)
  if numel(idx) == length(idx)
    idx = idx(:);
    val = val(:);
  end
  idx = num2cell(idx,1);
  val = num2cell(val,1);
end
nDatasets = length(idx);

% process or read in the roi specification
if nargin < 3 || isempty(roi), roi = false; end
if islogical(roi)
  flgRoi = roi;
  if flgRoi
    roi = idx;
  else
    roi = repmat({':'},1,nDatasets);
  end
else
  if ischar(roi)
    if ~isempty(regexp(roi,'\.gii$','once'))
      roiData = gifti(roi);
      % allow multiple sub-volumes
      nRoi = size(roiData.cdata,2);
      roi = cell(1,nRoi);
      for c = 1:nRoi
        roi{c} = find(roiData.cdata(:,c) > 0);
      end
    else
      roi = dlmread(roi);
    end
  end
  % support multiple columns
  if ~iscell(roi)
    if numel(roi) == length(roi), roi = roi(:); end
    roi = num2cell(roi,1);
  end
  nRoi = size(roi,2);
  if nRoi == 1
    roi = repmat(roi,1,nDatasets);
  elseif nRoi ~= nDatasets
    error('Number of subvolumes of the metric and the roi files do not match');
  end   
  % constrain the vertex indices by the region-of-interest
  for c = 1:nDatasets
    idxRoi = ismember(idx{c},roi{c});
    idx{c} = idx{c}(idxRoi);
    val{c} = val{c}(idxRoi);
  end
end

% read in and process the surface area weights
if nargin > 3 && ~isempty(area)
  area = gifti(area);
  for c = 1:nDatasets
    val{c} = val{c} .* area.cdata(idx{c});
  end
end


%% magic
%------------------------------

cogList = nan(1,nDatasets);
for c = 1:nDatasets
  % extract vertex vectors and normalise to unit length
  xyz = sphere.vertices(idx{c},:);
  unitLength = cellfun(@norm,num2cell(xyz,2));
  xyz = bsxfun(@rdivide,xyz,unitLength);
  unitLength = mode(unitLength);

  % average the vectors weighted by the metric
  cog = sum(bsxfun(@times,val{c},xyz),1)./sum(val{c},1);

  % extract vertex coordinates to match centre-of-gravity to
  xyz = sphere.vertices(roi{c},:);

  % normalise the centre-of-gravity vector
  cog = unitLength*cog/norm(cog); % one could normalise the xyz, but this takes longer, and is only better is vectors have different unit length

  % find the vertex closest to the centre-of-gravity vector
  [~,idxClosest] = min(euclid(xyz,cog));
  if isequal(roi{c},':')
    cogList(c) = idxClosest;
  else
    cogList(c) = roi{c}(idxClosest);
  end
end
cog = cogList;
