# matlab_autotest
Tool to add automatic checkpoints to messy code (that can later be turned into unit tests).

This is not meant to be a replacement for a carefully written [Testing Framework](https://uk.mathworks.com/help/matlab/matlab-unit-test-framework.html).
Rather, it is a development tool to refactor code that has little or no tests; to make sure that, as you tidy up the code (and write propper tests) it continues to produce the same outputs.

## Structure
The repo defines three classes:
+   [`TestCheckpoint`](TestCheckpoint.m) defines individual _test objects_ (see [Usage](#usage) below)
+   [`WorkspaceBackup`](WorkspaceBackup.m) is a wrapper around [`save`](https://uk.mathworks.com/help/matlab/ref/save.html). It allows `TestCheckpoint` to do workspace dumps from the caller environment, with additional options (e.g. to exclude certain classes).
+   [`TestSession`](TestSession.m) is used to store a _static_ (global-like)[^1] index of test objects. It allows these to be accessed from anywhere in the code, via the structure `TestCheckpoint.session.tests`.
  
[^1]: <https://uk.mathworks.com/help/matlab/matlab_oop/static-data.html>

## Usage

### 1. Define tests
    
+   Test objects include a unique `id`, and `input` and `output` options (`WorkspaceBackup` objects) that define which variables are to be (re)stored before and after the code to be tested.
+   Every test object will be pushed to the static  index, as `TestCheckpoint.session.tests.(id)`

```matlab
function define_test_objects()
% Has to run before instrumented code

    % Object will become available as TestCheckpoint.session.tests.test_dummy
    TestCheckpoint('test_dummy', 'input', {'onlynames', {'x','y'}}, 'output', {'onlynames', 'z'});
end
```

### 2. Instrument code

+   Retrieve a test from `TestCheckpoint.session.tests`
+   Use `obj.do('input')` and `obj.do('output')` to mark the spots right before and after the code to be tested:

```matlab
function z = instrumented_function(x, y)

    % Get test object -- requires a previous call to TestCheckpoint('test_dummy',...)
    obj = TestCheckpoint.session.tests.test_dummy;

    % insert right before code to be tested
    obj.do('input');

    % Do stuff
    z = dummy(x, y);

    % insert right after code to be tested.
    obj.do('output');
end
```

### 2. Do a `'setup'` run

When the `state` flag of a test object `obj` is set to `'setup'` (default, if there are no backup files associated with `id`):

+   `obj.do('input')` - Will save all reference workspace inputs, into `obj.input.file`.
+   `obj.do('output')` - Will save all reference workspace outputs, into `obj.output.file`.

### 3. Modify the code

While `obj.state == 'idle'` (once reference files have been stored in a `setup` run), calls to `obj.do` will not do anything.

### 4. Do a `'test'` run

If the `state` flag of a test object `obj` is set to `test` (this must be done explicitly):

+   `obj.do('input')` - Will **restore** all reference workspace inputs, from into `obj.input.file`.
+   `obj.do('output')` - Will save all test workspace outputs, into **`obj.test_io.file`**.

Compare the contents of `obj.test_io.file` and `obj.output.file`

**TODO**: This should be done automatically, perhaps generating a test-script with references to the test files

### 5. (Optional) reset

Use `TestCheckpoint.session.reset(true)` to delete all test objects and their associated files.

