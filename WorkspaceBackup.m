classdef WorkspaceBackup
% WORKSPACEBACKUP - helper class to save/restore variables in workspace.
% 
%   Without further arguments, the call:
% 
%       obj = WORKSPACEBACKUP('foo.mat');
%       obj.backup();
%
%   Is in most cases equivalent to save('foo.mat'). 
% The main method can be summarized as:
%
%       obj.backup = @() evalin(obj.workspace, 'save(<variables>)')  
%
%   where the list of <variables> is parsed 
%
% Properties:
%
%   file - backup file name
%   skipnames  - (optional) variables in workspace that should not be saved
%   skipclasses - (optional) variables with classes that should not be saved
%   onlynames - (optional) exclusively save variables in this list
%   onlyclasses - (optional) exclusively save variables with classes in this list
%   workspace  - 'base' or 'caller' (default)
%   verbose
%
% Methods:
%
%   obj.backup() - Parse variable list (based on properties), and save to file.
%
% Examples:
%
%   % Almmost* equivalent to save('foo.mat', 'a', 'b', 'c'):
%   obj = WORKSPACEBACKUP('foo.mat', 'onlynames', {'a','b','c'}); 
%   obj.backup();
%
%   % Almmost* equivalent to evalin('base','save ''foo.mat''')
%   obj = WORKSPACEBACKUP('foo.mat','workspace','base'); obj.backup();
%
%   % (*) For exact equivalents, make sure to set 'skipclasses', {}
%
%   % Thigs that are clunkier to do with save:
%   obj = WORKSPACEBACKUP(file, 'skipnames', {'trash','foo'}); obj.backup();
%   obj = WORKSPACEBACKUP(file, 'onlyclasses', {'double'}); obj.backup();
%
%   obj = WORKSPACEBACKUP(file, 'skipnames', {'a','b','c'}, 'skipclasses', {'matlab.graphics'});
%   ...
%   if there_is_danger, obj.backup; end
%   ...
%   obj.backup; % again, for some other reason
%
% See also: save, evalin, assignin

properties
    file char {mustBeTextScalar} = '' % Backup file name
    skipnames (1,:) string {mustBeText} = {}  % Variables in workspace that should not be saved
    skipclasses (1,:) string {mustBeText} =  WorkspaceBackup.SKIPCLASSES % Variables with classes that should not be saved
    onlynames (1,:) string {mustBeText} = {}  % Exclusively save variables in this list
    onlyclasses (1,:) string {mustBeText} = {}  % Exclusively save variables with classes in this list
    workspace char {mustBeTextScalar, mustBeMember(workspace, {'caller', 'base'})} = 'caller'  % Workspace option: 'base' or 'caller' (default)
    verbose (1,1) logical = false  % Show status messages? (logical)
    interactive (1,1) logical = usejava('desktop') && feature('ShowFigureWindows')  % Questdlg during obj.restore? (logical)
end

properties (Constant, Hidden)
    SKIPCLASSES = {'matlab.graphics', 'distributed', 'parallel.ProcessPool','onCleanup',...
        'function_handle','WorkspaceBackup','TestCheckpoint'};
end

methods
    function obj = WorkspaceBackup(varargin)
    % WORKSPACEBACKUP(FILE, ...) takes all other properties as name/value pairs.

        if nargin == 0, return; end
        obj = set(obj, 'file', varargin{:});
    end

    function obj = set(obj, names, values)
    % obj = obj.SET('name', val, ...) - set multiple properties at once

        arguments
            obj WorkspaceBackup
        end
        arguments (Repeating)
            names char {mustBeTextScalar}
            values
        end

        for j = 1:numel(names)
            obj.(names{j}) = values{j};
        end

        if nargout == 0
            warning('WorkspaceBackup:set:nargout','This is not a handle class, set properties will be lost')
        end
    end

    function obj = set.file(obj, val)
    % Make sure obj.file is a valid .mat file path

        if isempty(val), obj.file = ''; return; end

        mustBeTextScalar(val);
        [path, base, ext] = fileparts(val);

        assert(isempty(path) || isfolder(path), 'WorkspaceBackup:setfile:path', 'Failed to find path %s', path);
        
        assert(~isempty(regexp(base, '^[\w\-. ]+$', 'once')), 'WorkspaceBackup:setfile:name', ...
            'Invalid file name: "%s", make sure to write hidden files with .mat extension', base)

        if isempty(ext), ext = '.mat'; end
        assert(strcmp(ext, '.mat'), 'WorkspaceBackup:setfile:ext', ...
            'WorkspaceBackup currently only supports .mat file extensions');

        obj.file = fullfile(path, [base ext]);
    end
    
    function varargout = backup(obj, dryrun)
    % BACKUP(OBJ) - Parse variable list on OBJ.workspace, filtering by non-empty OBJ.only* and OBJ.skip* properties,
    %   then and save variables to OBJ.file
    %
    % [OBJ, VARS] = OBJ.BACKUP - return original object*, and cellstr of saved variables.
    %   (*) this is to allow the syntax: OBJ = WorkspaceBackup('myfile.mat').BACKUP();
    %
    % [OBJ, VARS] = OBJ.BACKUP(DRYRUN) - if DRYRUN = true, just returns the list of variables that would be saved
    
        arguments
            obj WorkspaceBackup
            dryrun (1,1) logical = false
        end

        varnames = evalin(obj.workspace,'who');

        if ~isempty(obj.onlynames)
            varnames = intersect(varnames, obj.onlynames);
        end

        if ~isempty(obj.skipnames)
            varnames = setdiff(varnames, obj.skipnames);
        end
    
        if ~isempty(obj.skipclasses) || ~isempty(obj.onlyclasses)
            varinfo = evalin(obj.workspace, WorkspaceBackup.quotedcmd('whos', varnames));

            if ~isempty(obj.skipclasses)
                bad = arrayfun(@(x) contains(x.class, obj.skipclasses), varinfo);
                varnames(bad) = [];
                varinfo(bad) = [];
            end
            if ~isempty(obj.onlyclasses)
                varnames(~arrayfun(@(x) contains(x.class, obj.onlyclasses), varinfo)) = [];
            end
        end

        if obj.verbose
            if isempty(varnames)
                fprintf('Nothing to save\n');
            elseif dryrun
                fprintf('DRY-RUN: would save %d variables to file: %s\n', numel(varnames), obj.file);
            else
                fprintf('Saving %d variables to file: %s\n', numel(varnames), obj.file);
            end
        end

        if ~isempty(varnames) && ~dryrun
            evalin(obj.workspace, WorkspaceBackup.quotedcmd('save', [{obj.file}; varnames]));
        end

        if nargout > 0, varargout = {obj, varnames}; end
    end
    
    function varargout = restore(obj, variables)
    % RESTORE(OBJ) - load OBJ.file (if exists) onto OBJ.workspace, optionally* after QUESTDLG.
    % S = RESTORE(OBJ) - return OBJ.file contents as structure
    % .. = RESTORE(OBJ, VARIABLES) - load/return only a subset of variables
    
        if nargin < 2, variables = {}; end
        variables = cellstr(variables);

        doload = false;
        if isfile(obj.file)
            if obj.interactive
                switch questdlg(['Do you want to resume from ', obj.file, '?'])
                    case 'Yes', doload = true;
                    case 'No'
                    case 'Cancel', error('Stopped by user')
                end
            else
                doload = true;
            end
        else
            error('%s file does not exist', obj.file);
        end

        if ~doload
            if nargout > 0, varargout{1} = struct(); end
            return;
        end

        if nargout == 0
            evalin(obj.workspace, strjoin([{'load', obj.file}, variables],' '));
            if obj.verbose, fprintf('Loaded %s onto %s workspace', obj.file, obj.workspace); end
        else
            varargout{1} = load(obj.file, variables{:});
        end
    end         
end

methods(Static, Hidden)

    function s = quotedcmd(cmd, args)
    % QUOTEDCMD('cmd', {'a','b'}) - returns a string 'cmd('a','b')' suitable for evalin
        s = [cmd '(''' char(strjoin(args,''', ''')) ''')'];
    end
end

end

