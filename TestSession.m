classdef TestSession < handle

    properties
      index = struct('id',{})
      path char {mustBeFolderOrEmpty} = fullfile(fileparts(mfilename('fullpath')),'tests');
    end

    properties (Constant)
        indexfile char {mustBeTextScalar} = '.TestSessionIndex.mat'
    end

    methods
        function varargout = exists(obj, id)
            mustBeTextScalar(id);
            [varargout{1:nargout}] = ismember(id, {obj.index.id});
        end

        function push(obj, test)

            validateattributes(test,'TestCheckpoint', {'scalar'});

            if isempty(obj.index)
                obj.index = test;
            else
                [~, idx] = exists(obj, test.id);
                if idx > 0
                    warning('TestSession:push:exists','Overwriting test %s', test.id);
                    obj.index(idx) = [];
                end
                obj.index(end+1) = test;
            end
        end

        function reset(obj, remove_files)

            if nargin < 2, remove_files = false; end
            validateattributes(remove_files,'logical',{'scalar'});

            if remove_files
                files = [arrayfun(@(x) x.input.file, obj.index, 'unif',0), ...
                         arrayfun(@(x) x.output.file, obj.index, 'unif',0)];
                files(~cellfun(@isfile, files)) = [];
                cellfun(@delete,files);
            end

            obj.index = struct('id',{});
        end

        function rm(obj, id)

        end
    end
end

function mustBeFolderOrEmpty(txt)
    try
        mustBeTextScalar(txt);
        if ~isempty(txt), mustBeFolder(txt); end
    catch ERR
        throwAsCaller(ERR);
    end
end