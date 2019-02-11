function CC = km_calculateD(CC, roi_path, surf_path, varargin)
% Function to calculate distance matrix of all the voxels in a region of
% interest and combine it with a previously calculated cross-correlation
% matrix. 
%--------------------------------------------------------------------------
% Dependency: workbench command
%--------------------------------------------------------------------------
%
% Use
%   km_calculateD(CC, path_to_ROI, path_to_surface_file)
%
% Obligatory input:
%   CC          cross-correlation matrix
%   roi_path    path to your region of interest (mask.func.gii file)
%   surf_path   path to the surface file off of which distances need to be 
%               measured (hemisphere.surf.gii file)
%
% Optional inputs (using parameter format):
%   fudge_factor    takes values in range [0 1]
%                   0.2 (default)
%   dist_method     method to be used to calculate distances 
%                   geodesic (default)
%
% Output
%   CC          weighted combination of cross-correlation matrix and
%               distance matrix
%
% version history
% 2016-05-04	suhas       integrated geodesic distances, documentation 
% 2015          lennart     implemented pdist
%
% copyright
% Rogier B. Mars
% University of Oxford & Donders Institute, 2016
    
    % defaults
    con     = 0.2; % con is the fudge factor between 0 and 1    
    dist    = 'geodesic';
    D       = [];
    
    if nargin>3
        for vargnr = 2:2:length(varargin)
            switch varargin{vargnr-1}
                case 'fudge_factor'
                    con = str2double(varargin{vargnr});
                case 'dist_method'
                    dist = varargin{vargnr};
            end
        end
    end   
    
    surf    = gifti(surf_path);
    roi     = gifti(roi_path);
    
    switch lower(dist)
        
        case {'euclidean', 'cosine', 'mahalanobis', 'seuclidean'}
            
            fprintf('Creating distance matrix using method: %s \n\n', dist)
            
            vertices = surf.vertices(roi.cdata > 0);             
            
            % calculate distances 
            D = pdist(vertices, dist);
            D = squareform(D);

            % % Temporary fix, brutally cut D to match the size of CC. ERROR:
            % % This is of course not valid!!! Work need to be done!
            % D = D(1:size(CC,1),1:size(CC,2));
        
        case 'geodesic'
            
            fprintf('Creating distance matrix using method: %s \n\n', dist)
            
            vertices = find(roi.cdata); % Get vertices from seed mask as indeces 
            for i = 1: length(vertices)

                from_this_vertex = num2str(vertices(i));
                
                % calculate geodesic distances using workbench command
                if ismac
                    path_wb = '/Applications/workbench/bin_macosx64/';
                    unix([path_wb 'wb_command -surface-geodesic-distance ' surf_path ' ' from_this_vertex ' temp.func.gii']);                
                elseif isunix % Implemented to work on DCC cluster 
                    path_wb = '/vol/optdcc/workbench/bin_linux64/';
                    unix([path_wb 'wb_command -surface-geodesic-distance ' surf_path ' ' from_this_vertex ' temp.func.gii']);
                else
                    error 'Implemented to work locally on macs and on Donders cluster. Please manually edit path to workbench command.';
                end

                temp = gifti('temp.func.gii');
                % concatenate distances for each of the roi vertex
                D = [D , temp.cdata];
                % delete file - wb_command creates a distance .func.gii file for each vertex
                delete('temp.func.gii'); clear temp;

            end

            % restrcit distance matrix to (roi x roi) dimensions 
            D = D(vertices,:);
            
    end
    
    % scale D to min and max of both CC and D
    D = max(D(:))-D;
    m = min(D(:));
    M = max(D(:));
    R = max(CC(:));
    r = min(CC(:));
    D = (D-m)*(R-r)/(M-m)+r;
    
    % weighted combination of CC and D to submit to clustering algorithm
    fprintf('Combining CC and D with a fudge factor of: %.2f \n \n', con);
    CC = sqrt( (1-con)*CC.*CC + con*D.*D);
end
