function tests = TestCheckpointTest()
% Tests for WorkspaceBackup class

    tests = functiontests(localfunctions);
end

function setupOnce(testCase)

    addpath('..');

    testCase.TestData.session = TestCheckpoint.session;
    testCase.TestData.origPath = testCase.TestData.session.path;
    tmpdir = tempname();
    mkdir(tmpdir)
    testCase.TestData.session.path = tmpdir;
end

function teardownOnce(testCase)
    rmdir(testCase.TestData.session.path,'s');
    testCase.TestData.session.path = testCase.TestData.origPath;
end

function teardown(testCase)
    testCase.TestData.session.reset(true);
end

function test_empty(testCase)
    obj = TestCheckpoint.empty;
    verifyEmpty(testCase, obj);
end

function test_constructor(testCase)
% Just check that setup worked alright

    obj = TestCheckpoint('foo','bar');

    verifyInstanceOf(testCase, obj,'TestCheckpoint');
    verifyEqual(testCase, obj.id, 'foo');
    verifyEqual(testCase, obj.call, "bar");

    verifyInstanceOf(testCase, obj.input,'WorkspaceBackup');
    verifyInstanceOf(testCase, obj.output,'WorkspaceBackup');
    verifyNotEmpty(testCase, obj.input.file);
    verifyNotEmpty(testCase, obj.output.file);

    verifySameHandle(testCase, obj.session, testCase.TestData.session);
end

function [obj, x, y, z] = example(varargin)
% Return a TestCheckpoint object, and variables to test it with

    % "personalize" ID, so that it is different for each test
    s = dbstack(1);
    id = s(1).name;

    obj = TestCheckpoint(id,'dummy(x,y)', varargin{:}, ...
            'input', {'onlynames', {'x','y'}}, ...
            'output', {'onlynames', 'z'});
    x = 1;
    y = 2;
    z = dummy(x,y);
end

function w = dummy(a, b)

    % uses some variable names from outside, for confusion
    z = 42;
    x = 3;

    w = a * b + z + x;
end

function test_full_constructor(testCase)
    obj = example('state','idle','spyname','foo');
    verifyInstanceOf(testCase, obj,'TestCheckpoint');

    verifyEqual(testCase, obj.state,'idle');
    verifyNotEmpty(testCase, obj.spyname,'foo');
end

function test_session_index(testCase)
    
    obj = TestCheckpoint('test_1','foo');

    verifyInstanceOf(testCase, TestCheckpoint.session.tests, 'struct');
    verifyTrue(testCase, isfield(TestCheckpoint.session.tests,'test_1'));

    verifyInstanceOf(testCase, TestCheckpoint.session.tests.test_1,'TestCheckpoint');
    verifySameHandle(testCase, obj, TestCheckpoint.session.tests.test_1);

    verifyWarning(testCase, @() TestCheckpoint('test_1','foo'), 'TestSession:push:exists');
    verifyWarningFree(testCase, @() TestCheckpoint('test_2','foo'));
    verifyEqual(testCase, TestCheckpoint.session.ids, {'test_1','test_2'}');
end

function test_hard_index(testCase)
% Check that session index is stored persistently in session.indexfile

    TestCheckpoint('test_1','foo');
    TestCheckpoint('test_2','bar');
    TestCheckpoint('test_3','bam');

    TestCheckpoint.session.reset(false)
    verifyEqual(testCase, TestCheckpoint.session.ids, cell(0,1));

    TestCheckpoint.session.restore();
    verifyEqual(testCase, TestCheckpoint.session.ids, {'test_1','test_2','test_3'}');
end

function test_idle(testCase)
% check obj.do does nothing when obj.state = 'idle'

    [obj, x, y] = example('state','idle'); %#ok<ASGLU>
    assert(~isfile(obj.input.file));

    obj.do('input');
    obj.do('output');
    verifyTrue(testCase, ~isfile(obj.input.file))
    verifyTrue(testCase, ~isfile(obj.output.file))
end

function test_setup_input(testCase)
% check obj.do('input') creates backup when obj.state = 'setup';

    [obj, x, y] = example('state','setup');
    assert(~isfile(obj.input.file));

    obj.do('input');
    verifyTrue(testCase, isfile(obj.input.file))
    verifyEqual(testCase, obj.input.restore, struct('x', x, 'y', y));
end

function test_non_intrusive(testCase)
% obj.do will temporarily copy a variable (named TestCheckpoint.DEF_SPYNAME by default) into the caller workspace
% it should be renamed if it clashes with an already existing name

    [obj, x, y] = example('state','setup'); %#ok<ASGLU>

    eval([TestCheckpoint.DEF_SPYNAME '= [];']);

    obj.do('input');
    verifyEmpty(testCase, eval(TestCheckpoint.DEF_SPYNAME));
end

function test_spyname(testCase)
% Regardless of the variable name, assignin('caller', VAR, val) will fail unless VAR already exists in the workspace.
% Check that specifying an explicit obj.spyname (predefined in the workspace) solves the issue.

    obj = example('state','setup');

    verifyError(testCase, @do_backup, 'TestCheckpoint:do:err_static_workspace_violation');

    obj.spyname = 'foo';
    verifyWarningFree(testCase, @do_backup);

    function do_backup()
        x = 0; y = 0; foo = []; %#ok<NASGU
        obj.do('input');
    end
end

function test_setup_output(testCase)
% check obj.do('output') creates backup when obj.state = 'setup'
% and that it complains when that happens before obj.do('input')

    obj = example('state','setup','spyname','foo');

    assert(~isfile(obj.input.file));
    assert(~isfile(obj.output.file));

    verifyWarning(testCase, @do_output, 'TestCheckpoint:do:order');
    verifyTrue(testCase, isfile(obj.output.file))
    verifyEqual(testCase, obj.output.restore, struct('z', 42));

    function do_output()
        z = 42; foo = []; %#ok<NASGU>
        obj.do('output');
    end
end

function test_auto(testCase)
% basic auto-setup cycle for fresh test

    [obj, x, y] = example(); %#ok<ASGLU>
    assert(~isfile(obj.input.file));
    assert(~isfile(obj.output.file));

    verifyEqual(testCase, obj.state,'setup')

    obj.do('input');
    obj.do('output');
    verifyTrue(testCase, isfile(obj.input.file))
    verifyTrue(testCase, isfile(obj.input.file))
    verifyEqual(testCase, obj.state,'idle')
end

function test_instrumented_script(testCase)
% basic auto-setup cycle for fresh test

    [obj,x,y] = example();

    % Setup run
    z = instrumented_function(x,y);

    verifyTrue(testCase, isfile(obj.input.file));
    verifyTrue(testCase, isfile(obj.output.file));

    % Test run
    obj.state = 'test';
    instrumented_function(x+1, y+1);

    verifyTrue(testCase, isfile(obj.test_io.file));
    verifyEqual(testCase, obj.test_io.restore(), struct('z',z))
end

function z = instrumented_function(x, y)

    obj = TestCheckpoint.session.tests.test_instrumented_script;
    obj.do('input');

    z = dummy(x, y);

    obj.do('output');
end


