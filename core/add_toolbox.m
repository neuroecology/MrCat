function p_toolbox = add_toolbox(s_toolbox,p_search,flg_recursive,flg_force)
%--------------------------------------------------------------------------
% Adds specified toolbox to path if applicable. Reverts back to default on
% Rogier's Mac if toolbox cannot be found
%
% Input
%   s_toolbox       name of the toolbox (string)
% Optional
%   p_search        path to search for toolbox
%   flg_recursive   add subfolders of toolbox folder or not
%   flg_force       add toolbox to path even if a copy is already present
%
% Output
%   p_toolbox       path of the toolbox
%
%
% version history
% 2015-02-01    Lennart added recursive search using unix' find
% 2014-11-01    Lennart added flg_force functionality
% 2014-04-01    Lennart created
%
% Lennart Verhagen & Rogier B. Mars
% University of Oxford, 2014-04-01
%--------------------------------------------------------------------------

%% housekeeping
%-------------------------------
narginchk(1,4);
if nargin<4 || isempty(flg_force), flg_force = false; end
if ischar(flg_force), flg_force = isequal(flg_force(1),'f'); end
if nargin<3 || isempty(flg_recursive), flg_recursive = false; end
if ischar(flg_recursive), flg_recursive = isequal(flg_recursive(1),'r'); end

% if no search path is supplied use path of current mfile first
if nargin < 2 || isempty(p_search)
    p_search = fileparts(mfilename('fullpath'));
end


%% core
%-------------------------------
% loop over several stages in the search for the toolbox
flg = false; stage = 0;
while ~flg
    stage = stage + 1;
    switch stage
        case 1
            % test if toolbox is already on path
            if ~flg_force && ~isempty(regexp(path,s_toolbox,'match','once'))
                % get path of toolbox from path
                pp = regexp(path,':','split');
                p_toolbox = pp{~cellfun(@isempty,regexp(pp,s_toolbox))};
                flg = true;
            end
        case 2
            % search on search path
            p_toolbox = fullfile(p_search,s_toolbox);
            if exist(p_toolbox,'dir')==7, flg = true; end
        case 3
            % use unix find to search for subfolders on the search path
            unixcmd = sprintf('find %s -name ''%s''',p_search,s_toolbox);
            [~,p_toolbox] = unix(unixcmd);
            if exist(p_toolbox,'dir')==7, flg = true; end
        case 4
            % give warning at this stage if search path was specified
            if nargin == 2
                warning('ADD_TOOLBOX:toolbox_not_on_search_path','''%s'' toolbox is not found on the specified search path, continuing search in the user folder.',s_toolbox);
            end
            % restrict search depending on the user name
            switch getenv('USER')
                case 'rogiermars'
                    p_toolbox = fullfile('Users','rogiermars','matlab_toolboxes',s_toolbox);
            end
            if exist(p_toolbox,'dir')==7, flg = true; end
        case 5
            p_search = strrep(userpath,pathsep,'');
            % search in root of user folder
            p_toolbox = fullfile(p_search,s_toolbox);
            if exist(p_toolbox,'dir')==7, flg = true; end
        case 6
            % search in an obvious subfolder of the user folder
            p_toolbox = dir(fullfile(p_search,'*toolbox*'));
            p_toolbox = fullfile(p_search,p_toolbox(1).name,s_toolbox);
            if exist(p_toolbox,'dir')==7, flg = true; end
        case 7
            % use unix find to search for subfolders in the user path
            unixcmd = sprintf('find %s -name ''%s''',p_search,s_toolbox);
            [~,p_toolbox] = unix(unixcmd);
            if exist(p_toolbox,'dir')==7, flg = true; end
        case 8
            p_search = strrep(userpath,'matlab','dropbox');
            % use unix find to search for subfolders in the user dropbox
            unixcmd = sprintf('find %s -name ''%s''',p_search,s_toolbox);
            [~,p_toolbox] = unix(unixcmd);
            if exist(p_toolbox,'dir')==7, flg = true; end
        otherwise
            error('''%s'' toolbox not found',s_toolbox);
    end
end

% force p_toolbox to only the first found instance
p_toolbox = regexp(p_toolbox,'\n','split'); p_toolbox = p_toolbox{1};

% add toolbox to path if not yet included
if stage > 1
    if flg_recursive % but don't include hidden folders
        addpath(rmpathstr(genpath(p_toolbox),'\.'));
    else
        addpath(p_toolbox);
    end
end