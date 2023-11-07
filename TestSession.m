classdef TestSession < handle

    properties
      tests = struct()
      path char {mustBeFolderOrEmpty} = fullfile(fileparts(mfilename('fullpath')),'tests');
    end

    properties (Dependent)
        ids
        indexfile
    end

    properties (Constant)
        indexname char {mustBeTextScalar} = '.TestSessionIndex.mat'
    end

    methods
        function yn = exists(obj, test)
        % more sofisticated tests to follow?
            mustBeA(test,'TestCheckpoint');
            yn = isfield(obj.tests, test.id);
        end

        function ids = get.ids(obj), ids = fieldnames(obj.tests); end

        function filepath = get.indexfile(obj), filepath = fullfile(obj.path, obj.indexname); end

        function set.path(obj, path)
        % Make sure path exists
            if isempty(path), path = fullfile(fileparts(mfilename('fullpath')),'tests'); end
            assert(isfolder(path),'Failed to find folder: %s', path);
            obj.path = path;
        end

        function push(obj, test)

            validateattributes(test,'TestCheckpoint', {'scalar'});

            if exists(obj, test)
                warning('TestSession:push:exists','Overwriting test %s', test.id);
            end
            obj.tests.(test.id) = test;

            s = struct(test.id, test);
            if ~isfile(obj.indexfile)
                save(obj.indexfile,'-struct','s');
            else
                save(obj.indexfile,'-struct','s','-append');
            end
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

                files = [{obj.indexfile}, ...
                         {obj.all('input').file}, ...
                         {obj.all('output').file}, ...
                         {obj.all('test_io').file}];

                files(~cellfun(@isfile, files)) = [];
                cellfun(@delete,files);
            end

            obj.tests = struct();
        end

        function restore(obj, indexfile)
            if nargin < 2
                indexfile = obj.indexfile; 
            else
                obj.path = fileparts(indexfile);
            end
            T = load(indexfile);
            fld = fieldnames(T);
            for j = 1:numel(fld)
                validateattributes(T.(fld{j}),{'TestCheckpoint'},{'scalar'});
                T.(fld{j}).state = '';
            end
            obj.tests = T;
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