function tests = TestCheckpointTest()
% Tests for WorkspaceBackup class

    tests = functiontests(localfunctions);
end

function setupOnce(testCase)

    addpath('..');

    testCase.TestData.session = TestCheckpoint.session;
    testCase.TestData.origPath = testCase.TestData.session.path;
    testCase.TestData.session.path = tempdir();
end

function teardownOnce(testCase)
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

function [obj, x, y, z] = example(id)
% Return a TestCheckpoint object, and variables to test it with

    obj = TestCheckpoint(id,'dummy(x,y)', 'state', '', ...
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
    obj = example('test_full_constructor');
    verifyInstanceOf(testCase, obj,'TestCheckpoint');
end

function test_session_index(testCase)
    example('test_session');
    verifyWarning(testCase, @() example('test_session'), 'TestSession:push:exists');
    verifyWarningFree(testCase, @() example('test_session_2'));
    verifyEqual(testCase,{TestCheckpoint.session.index.id},{'test_session','test_session_2'});
end

function test_idle(testCase)
% check obj.do does nothing when obj.state = 'idle'

    [obj, x, y] = example('test_idle'); %#ok<ASGLU>
    obj.state = 'idle';
    assert(~isfile(obj.input.file));

    obj.do('input');
    obj.do('output');
    verifyTrue(testCase, ~isfile(obj.input.file))
    verifyTrue(testCase, ~isfile(obj.output.file))
end

function test_setup_input(testCase)

    [obj, x, y] = example('test_setup');
    obj.state = 'setup';
    assert(~isfile(obj.input.file));

    obj.do('input');
    verifyTrue(testCase, isfile(obj.input.file))
    verifyEqual(testCase, obj.input.restore, struct('x', x, 'y', y));
end

function test_non_intrusive(testCase)
% obj.do will temporarily copy a variable (named TestCheckpoint.spyname by default) into the caller workspace
% it should be renamed if it clashes with an already existing name

    [obj, x, y] = example('test_setup'); %#ok<ASGLU>
    obj.state = 'setup';

    eval([TestCheckpoint.spyname '= []']);

    obj.do('input');
    verifyEmpty(testCase, eval(TestCheckpoint.spyname));
end

function test_setup_output(testCase)

    [obj, ~, ~, z] = example('test_setup');
    obj.state = 'setup';
    assert(~isfile(obj.input.file));
    assert(~isfile(obj.output.file));

    verifyWarning(testCase, @do_output, 'TestCheckpoint:do:order');
    verifyTrue(testCase, isfile(obj.output.file))
    verifyEqual(testCase, obj.output.restore, struct('z', z));

    function do_output()
        z; %#ok<VUNUS>
        obj.do('output');
    end
end

function test_auto(testCase)

    [obj, x, y] = example('test_setup'); %#ok<ASGLU>
    assert(~isfile(obj.input.file));
    assert(~isfile(obj.output.file));

    obj.do('input');
    obj.do('output');
    verifyTrue(testCase, isfile(obj.input.file))
    verifyTrue(testCase, isfile(obj.input.file))
    verifyEqual(testCase, obj.state,'idle')
end

function instrumented_function()

    [obj, x, y] = example();

    % Record/set inputs (if global TEST_state = 'setup')
    obj.do('input');

    z = dummy(x, y);

    obj.do('output');

    dummy_test.output('onlynames', {'z'});

    % Run recorded test
    TEST_state = 'test';
    dummy();
    test_checkpoint('run', 'tester_test')

end

function foo()

    % global foo
    % foo = 42;

    x = 1;
    y = 2;

    % Record/set inputs (if global TEST_state = 'setup')
    dummy_test = test_checkpoint('dummy_test','dummy(x,y)');
    dummy_test.input('onlynames', {'x','y'});

    z = dummy(x, y);

    dummy_test.output('onlynames', {'z'});

    % Run recorded test
    TEST_state = 'test';
    dummy();
    test_checkpoint('run', 'tester_test')

end

