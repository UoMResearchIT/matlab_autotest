classdef TestCheckpoint < handle

    properties
        id char {mustBeTextScalar} % unique test identifyer
        call (1,:) string % code to run to get from input to output
        input WorkspaceBackup % Dump settings before call (WorkspaceBackup object, or cell-array of arguments for its construction) 
        output WorkspaceBackup % Dump settings after call (WorkspaceBackup object, or cell-array of arguments for its construction)
        state char {mustBeTextScalar, mustBeMember(state, {'','idle', 'setup','test'})} % See TestCheckpoint.do
    end

    properties( Constant)
        session (1,1) TestSession = TestSession() % defines default test-path, state, and index of tests
    end

    properties(Constant, Hidden)
        spyname = 'TestCheckpointIO'; % default name of WorkspaceBackup objects, when copied onto 'caller'
    end

    methods (Hidden)
        function name = filename(obj, type)
            mustBeMember(type, {'input','output','test'});
            name = fullfile(TestCheckpoint.session.path, [obj.id '_' type '.mat']);
        end
    end
    
    methods
        function obj = TestCheckpoint(id, call, opts)
        % TESTCHECKPOINT(ID, CALL, ...)
        % TESTCHECKPOINT(.., 'input', {<args>}) - provide optional arguments to WorkspaceBackup constructors

            arguments
                id char {mustBeTextScalar, mustBeValidVariableName}
                call (1,:) string {mustBeText}
                opts.input (1,:) cell = {}
                opts.output (1,:) cell = {}
                opts.state char {mustBeTextScalar, mustBeMember(opts.state, {'','idle', 'setup','test'})} = ''
            end

            obj.id = id;
            obj.call = call;
            
            obj.input = WorkspaceBackup(obj.filename('input'), 'interactive', 0, opts.input{:});
            obj.output = WorkspaceBackup(obj.filename('output'), 'interactive', 0, opts.output{:});

            obj.state = opts.state;
            if isempty(obj.state)
                if isfile(obj.input.file) && isfile(obj.output.file), obj.state = 'idle';
                else, obj.state = 'setup';
                end
            end

            % Register test in session.index
            obj.session.push(obj);
        end

        function do(obj, stage)
        % When recording tests (OBJ.state == 'setup'):
        %
        %   OBJ.DO('input') - run OBJ.input.backup in caller workspace (save state before call)
        %   OBJ.DO('output') - run OBJ.output.backup in caller workspace (save state after call)*
        %
        % When running tests (obj.state == 'test'):
        %
        %   OBJ.DO('input') - do OBJ.input.restore in caller workspace (restore state before call)
        %   OBJ.DO('output') - do OBJ.output.backup in caller workspace (save test output after call)*
        %
        % When idle (OBJ.state == 'idle'): do nothing

            if strcmp(obj.state,'idle'), return; end
            assert(~isempty(obj.state), 'OBJ.state cannot be empty');
            
            % get relevant WorspaceBackup object
            mustBeTextScalar(stage); 
            mustBeMember(stage,{'input','output'});
            wsb = obj.(stage); 

            % Get a variable name that we can assign in caller
            spy = obj.spyname;
            if evalin('caller', ['exist(''' spy ''')'])
                spy = matlab.lang.makeUniqueStrings(spy, evalin('caller','who'));
            end

            switch obj.state
            case 'setup'
            % [input/output].backup in caller workspace

                if isfile(wsb.file)
                    warning('TestCheckpoint:do:overwrite', 'Overwriting checkpoint: %s', wsb.file); 
                end
                if strcmp(stage,'output') && ~isfile(obj.input.file)
                    warning('TestCheckpoint:do:order', 'Writing checkpoint output before input'); 
                end

                assignin('caller', spy, wsb);
                evalin('caller', [spy '.backup']);
                evalin('caller', ['clear ' spy]);

            case 'test'

                assert(isfile(wsb.file), 'TestCheckpoint:do:notestfile', 'Failed to find checkpoint: %s', wsb.file);

                % Make sure our variable name will not be overwritten by restore
                spy = matlab.lang.makeUniqueStrings(spy, who('-file',wsb.file));
    
                switch stage
                case 'input'
                % input.restore in caller workspace

                    assignin('caller', spy, wsb);
                    evalin('caller', [spy '.restore']);
                    evalin('caller', ['clear ' spy]);

                case 'output'
                % dump to temp file, and read back as structure

                    wsb.file = obj.filename(obj.id,'test');

                    % [input/output].backup in caller workspace
                    assignin('caller', spy, wsb);
                    evalin('caller', [spy '.backup']);
                    evalin('caller', ['clear ' spy]);
                end
            end

            if strcmp(stage,'output'), obj.state = 'idle'; end
        end
    end
end