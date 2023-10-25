function varnames = all_vars_except(skipnames, skipclasses)
% ALL_VARS_EXCEPT(SKIPNAMES, SKIPCLASSES) - return a list of variables in the calling workspace, except for
%   those with names in SKIPNAMES, or those of type SKIPCLASSES.

    narginchk(0,2);
    if nargin < 1 || isempty(skipnames), skipnames = {}; end
    if nargin < 2 || isempty(skipclasses), skipclasses = {}; end
    try
        skipnames = cellstr(skipnames);
        skipclasses = cellstr(skipclasses);
    catch
        error('Expecting cellstrings for SKIPNAMES and SKIPCLASSES');
    end

    varnames = evalin('caller','who');

    if ~isempty(skipnames)
        varnames = setdiff(varnames, skipnames);
    end

    if ~isempty(skipclasses)
        varinfo = evalin('caller',['whos(''' strjoin(varnames,''', ''') ''')']);
        badclass = arrayfun(@(x) contains(x.class, skipclasses), varinfo);
        varnames = {varinfo(~badclass).name};
    end
end