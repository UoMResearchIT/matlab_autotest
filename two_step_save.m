function varargout = two_step_save(varargin)
% TWO_STEP_SAVE(FILE, VARIABLES) - store inputs and do nothing.
% TWO_STEP_SAVE() - run with stored inputs
% 
% Equivalent to save(FILE, VARIABLES{:}) in the calling workspace, but less clunky to use from a third function.
%
%   function foo()
%       ...
%       save_stuff_in_foo()
%   end
%
%   function save_stuff_in_foo()
%       TWO_STEP_SAVE('file.mat', '-stash');
%       evalin('caller','TWO_STEP_SAVE');
%   end
%
% See also: ALL_VARS_EXCEPT

    persistent args

    % TWO_STEP_SAVE() - run with stored inputs
    if nargin == 0
        assert(~isempty(args), 'Call with no arguments must be preceded by setup using -stash')
        varargin = args;
        args = {};
    end

    % TWO_STEP_SAVE(FILE, ... , '-stash')
    if ischar(varargin{end}) && startsWith(varargin{end},'-')
        assert(strcmpi(varargin{end},'-stash'),'Unrecognized flag %s', varargin{end});
        args = varargin(1:end-1);
        return;
    end

    [varargin{end+1:3}] = deal({});
    [file, skipnames, skipclasses] = deal(varargin{:});

    validateattributes(file,{'char','string'},{'scalartext'})
    try
        skipnames = cellstr(skipnames);
        skipclasses = cellstr(skipclasses);
    catch
        error('Expecting cellstrings for SKIPNAMES and SKIPCLASSES, use {} for empty');
    end

    varnames = evalin('caller','who');

    % We need a name VL to be used in the caller workspace as: evalin('caller','save(..., VL{:})')
    % make sure it doesn't already exist:
    var_list = matlab.lang.makeUniqueStrings('varlist', varnames);

    if ~isempty(skipnames)
        varnames = setdiff(varnames, skipnames);
    end
    assignin('caller', var_list, varnames);

    if ~isempty(skipclasses)
        vars = evalin('base',['whos(' var_list '{:})']);
        badclass = arrayfun(@(x) contains(x.class, skipclasses), vars);
        varnames = {vars(~badclass).name};
        assignin('caller', var_list, varnames);
    end

    if isfile(file)
        % If the file exists and is correupted, save will fail. Keep a hidden backup just in case
        [path, name, ext] = fileparts(file);
        movefile(file, fullfile(path, ['.',name ext]),'f')
    end

    disp(['Saving workspace to: ', file]);
    ERR = [];
    try
        evalin('caller',['save("' file '", ' var_list '{:})']);
    catch ERR
    end
    evalin('caller',['clear(''' var_list ''')']);
    if ~isempty(ERR), rethrow(ERR); end
    
    if nargout > 0, varargout{1} = var_list; end
end