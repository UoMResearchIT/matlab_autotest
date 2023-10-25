function backup(file, skipnames, skipclasses)
% BACKUP(FILE, SKIPNAMES, SKIPCLASSES) - save workspace to FILE, with
%   exception of variables SKIPNAMES, or those of type SKIPCLASSES.

    validateattributes(file,{'char','string'},{})
    if nargin < 2, skipnames = []; end
    if nargin < 3, skipclasses = []; end

    varnames = evalin('caller','who');

    % variable to be written in caller workspace,
    % make sure it doesn't exist.
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
        [path, name, ext] = fileparts(file);
        copyfile(file, fullfile(path, ['~',name ext]),'f')
    end

    disp(['Saving workspace to: ', file]);
    try
        evalin('caller',['save("' file '", ' var_list '{:})']);
    catch
        if isfile(file), delete(file); end
        try
            evalin('caller',['save("' file '", ' var_list '{:})']);
        catch ERR
            warning('Failed to backup: %s', getReport(ERR));
        end
    end

    evalin('caller',['clear(''' var_list ''')'])
end