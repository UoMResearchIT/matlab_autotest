classdef TestSession < handle

    properties
      tests = struct()
      path char {mustBeFolderOrEmpty} = fullfile(fileparts(mfilename('fullpath')),'tests');
    end

    properties (Dependent)
        ids
    end

    properties (Constant)
        indexfile char {mustBeTextScalar} = '.TestSessionIndex.mat'
    end

    methods
        function yn = exists(obj, test)
        % more sofisticated tests to follow?
            mustBeA(test,'TestCheckpoint');
            yn = isfield(obj.tests, test.id);
        end

        function ids = get.ids(obj), ids = fieldnames(obj.tests); end

        function push(obj, test)

            validateattributes(test,'TestCheckpoint', {'scalar'});

            if exists(obj, test)
                warning('TestSession:push:exists','Overwriting test %s', test.id);
            end
            obj.tests.(test.id) = test;
        end

        function pp = all(obj, prop)
            mustBeMember(prop, properties('TestCheckpoint'));
            try
                pp = structfun(@(x) x.(prop), obj.tests);
            catch ERR
                if ~strcmp(ERR.identifier, 'MATLAB:structfun:NotAScalarOutput'), rethrow(ERR); end
                pp = cellfun(@(x) obj.tests.(x).(prop), fieldnames(obj.tests), 'unif',0);
            end
        end

        function reset(obj, remove_files)

            if nargin < 2, remove_files = false; end
            validateattributes(remove_files,'logical',{'scalar'});

            if remove_files && ~isempty(obj.ids)
                files = [{obj.all('input').file}, {obj.all('output').file}, {obj.all('test_io').file}];
                files(~cellfun(@isfile, files)) = [];
                cellfun(@delete,files);
            end

            obj.tests = struct();
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