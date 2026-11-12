# ex_unit_erlang

[![CI](https://github.com/jessestimpson/ex_unit_erlang/actions/workflows/ci.yml/badge.svg)](https://github.com/jessestimpson/ex_unit_erlang/actions/workflows/ci.yml)

`ex_unit_erlang` runs test modules written in Erlang under ExUnit.

The library is for Mix projects that contain Erlang code. A test module is an
ordinary Erlang module that includes one header file. The test module uses the
OTP assert macros. `mix test` runs the Erlang tests and the Elixir tests in
the same run, with the same reporting, filters and exit status.

## Example

A test module:

```erlang
-module(my_math_tests).
-include_lib("ex_unit_erlang/include/ex_unit.hrl").

-async(true).

add_test() ->
    ?assertEqual(4, my_math:add(2, 2)).

divide_test() ->
    ?assertMatch({ok, _}, my_math:divide(1, 2)),
    ?assertEqual({error, division_by_zero}, my_math:divide(1, 0)).
```

The output of `mix test`:

```
$ mix test
Running ExUnit with seed: 231539, max_cases: 20

..
Finished in 0.05 seconds (0.05s async, 0.00s sync)
2 tests, 0 failures
```

## Requirements

- Elixir 1.19 or later.
- Erlang/OTP 27 or later.

## Installation

1. Add the dependency to `mix.exs`:

   ```elixir
   defp deps do
     [
       {:ex_unit_erlang, "~> 0.1", only: :test}
     ]
   end
   ```

2. Add three settings to the project configuration in `mix.exs`:

   ```elixir
   def project do
     [
       # ...
       erlc_paths: erlc_paths(Mix.env()),
       test_pattern: "*.{ex,exs,erl}",
       test_load_filters: [~r/_test\.exs$/, ~r/\.erl$/],
       deps: deps()
     ]
   end

   defp erlc_paths(:test), do: ["src", "test"]
   defp erlc_paths(_), do: ["src"]
   ```

   | Setting | Purpose |
   | --- | --- |
   | `erlc_paths` | Mix compiles the Erlang files under `test/` in the test environment. |
   | `test_pattern` | Mix considers `.erl` files under `test/` as test files. |
   | `test_load_filters` | Mix loads the `.erl` files, in addition to the `_test.exs` files. |

3. Call `ExUnitErlang.start/0` in `test/test_helper.exs`, after
   `ExUnit.start/0`:

   ```elixir
   ExUnit.start()
   ExUnitErlang.start()
   ```

A test module can be in any directory under `test/`. A test module can have
any name. The conventional name is `my_app_tests.erl`.

An Erlang file under `test/` that is not a test module, such as a helper
module, needs no configuration.

`ExUnitErlang.start/0` prints a warning when Mix will not load a test module.
The warning names the source file of the test module.

## Usage

### Tests

A test module includes the header file `ex_unit_erlang/include/ex_unit.hrl`.
Every function with a name that ends in `_test` and with arity 0 or 1 is a
test. A test does not need an `-export` attribute.

```erlang
-module(session_tests).
-include_lib("ex_unit_erlang/include/ex_unit.hrl").

expires_test() ->
    Session = session:new(#{ttl => 0}),
    ?assert(session:expired(Session)).
```

### Assertions

The header file includes `stdlib/include/assert.hrl`. A test can use every
macro that `assert.hrl` defines:

- `?assert`, `?assertNot`
- `?assertEqual`, `?assertNotEqual`
- `?assertMatch`, `?assertNotMatch`
- `?assertError`, `?assertExit`, `?assertThrow`, `?assertException`
- the variant of each macro that takes a comment

A helper module that includes `assert.hrl` or `eunit.hrl` directly is also
supported.

ExUnit reports a failed assertion with the source line of the assertion.
ExUnit reports a failed `?assertEqual` with a diff of the two terms.

```
  1) equal_test (:failing_tests)
     test/failing_tests.erl:8
     ?assertEqual failed (failing_tests, line 9)
     left is the expected term, right is the value
     code:  ?assertEqual({ok, [x, y]}, {ok, [x, id(z)]}).
     left:  {:ok, [:x, :y]}
     right: {:ok, [:x, :z]}
     stacktrace:
       test/failing_tests.erl:9: (test)

  2) match_test (:failing_tests)
     test/failing_tests.erl:11
     ?assertMatch failed (failing_tests, line 12)
     pattern: {ok, _}
     value: {error,division_by_zero}
     code: ?assertMatch({ok, _}, sample_math:divide(1, 0)).
     stacktrace:
       test/failing_tests.erl:12: (test)
```

ExUnit prints the `left:` and `right:` terms of a diff in Elixir syntax.
`ex_unit_erlang` prints all other terms in Erlang syntax.

### Context

A test with arity 1 receives the ExUnit context. The context is a map with
atom keys. The context contains:

- the tags of the test
- the values that `setup_all` and `setup` return
- the keys that ExUnit sets, such as `module`, `test`, `file`, `line`, `async`
  and `test_pid`

```erlang
name_test(#{test := Test, module := Module}) ->
    ?assertEqual(name_test, Test),
    ?assertEqual(?MODULE, Module).
```

The string values that ExUnit sets, such as `file` and `tmp_dir`, are
binaries.

### Callbacks

A test module can define the callbacks `setup_all` and `setup`. Each callback
has arity 0 or 1. A callback with arity 1 receives the context.

| Callback | When the callback runs | Process |
| --- | --- | --- |
| `setup_all` | Once, before the tests of the module. | A process that lives until the module finishes. |
| `setup` | Before each test. | The test process. |

A callback returns one of the following values:

| Return value | Effect |
| --- | --- |
| `ok` | The context does not change. |
| A map or a proplist | ExUnit merges the value into the context. |
| `{ok, MapOrProplist}` | ExUnit merges the map or the proplist into the context. |

```erlang
setup_all() ->
    Table = ets:new(?MODULE, [public]),
    {ok, #{table => Table}}.

setup(#{table := Table}) ->
    ets:delete_all_objects(Table),
    ok.

insert_test(#{table := Table}) ->
    ets:insert(Table, {key, value}),
    ?assertEqual([{key, value}], ets:lookup(Table, key)).
```

The module `ex_unit_erlang` provides functions for teardown and for supervised
processes:

| Function | Purpose |
| --- | --- |
| `ex_unit_erlang:on_exit(Fun)` | Runs `Fun` after the test finishes. When a `setup_all` callback calls the function, `Fun` runs after the module finishes. `Fun` runs whether the test passes or fails. |
| `ex_unit_erlang:on_exit(Name, Fun)` | Same as `on_exit/1`. A second call with the same `Name` replaces the first `Fun`. |
| `ex_unit_erlang:start_supervised(ChildSpec)` | Starts a child process. ExUnit stops the child process before the next test starts. |
| `ex_unit_erlang:start_supervised(ChildSpec, Opts)` | Same as `start_supervised/1`, with child spec overrides in `Opts`. |
| `ex_unit_erlang:stop_supervised(Id)` | Stops a child process that `start_supervised` started. |

```erlang
setup() ->
    {ok, Pid} = ex_unit_erlang:start_supervised(#{id => cache, start => {cache, start_link, []}}),
    ex_unit_erlang:on_exit(fun() -> file:delete("cache.dump") end),
    #{cache => Pid}.
```

### Module attributes

A test module sets options and tags with module attributes.

| Attribute | Meaning |
| --- | --- |
| `-async(true).` | ExUnit runs the module concurrently with other async modules. The default is `false`. |
| `-moduletag(Tag).` | Adds `Tag` to every test in the module. A module can have several `-moduletag` attributes. |
| `-tag(Tag).` | Adds `Tag` to the test function that follows the attribute. A test can have several `-tag` attributes. |

A tag has one of the following forms:

| Form | Example |
| --- | --- |
| An atom. The atom `slow` is equivalent to `{slow, true}`. | `-tag(slow).` |
| A `{Key, Value}` tuple. | `-tag({timeout, 120000}).` |
| A map with atom keys. | `-tag(#{owner => core}).` |
| A list of atoms and tuples. | `-tag([slow, {owner, core}]).` |

A `-tag` attribute overrides a `-moduletag` attribute that has the same key.

```erlang
-moduletag(integration).

-tag(slow).
-tag({timeout, 120000}).
import_test() ->
    ...
```

A tag is an ExUnit tag. ExUnit acts on the following tags:

| Tag | Effect |
| --- | --- |
| `skip` | ExUnit skips the test. `{skip, "reason"}` records the reason. |
| `{timeout, Milliseconds}` | Sets the timeout of the test. The default is 60000 ms. |
| `tmp_dir` | ExUnit creates an empty directory and adds the path to the context under the key `tmp_dir`. |
| `capture_log` | ExUnit captures the log output of the test. ExUnit prints the log output only when the test fails. |

### Compile-time checks

The Erlang compiler reports an invalid attribute, a duplicate test name or a
duplicate callback as a compile error with a file and a line.

```
test/my_tests.erl:6:2: -tag expects an atom, a {Key, Value} tuple, a map, or a list of atoms and tuples, got: "nope"
test/my_tests.erl:10:2: -tag must be followed by a test function (*_test/0 or *_test/1), but it is followed by helper/0
```

## Commands

`mix test` runs Erlang tests and Elixir tests. ExUnit identifies an Erlang
test by the module name and the function name.

| Selection | Command |
| --- | --- |
| All tests | `mix test` |
| One Erlang test module | `mix test test/session_tests.erl` |
| One test, by line | `mix test test/session_tests.erl:12` |
| One directory | `mix test test/integration` |
| One test, by name | `mix test --only test:expires_test` |
| One module, by name | `mix test --only module:session_tests` |
| Tests with a tag | `mix test --only slow` |
| Tests without a tag | `mix test --exclude integration` |
| Tests that failed in the previous run | `mix test --failed` |

One command line can contain Erlang test files and Elixir test files.

The options `--trace`, `--seed`, `--max-failures`, `--timeout` and
`--partitions` have the same effect on Erlang tests as on Elixir tests.

## Design

The header file enables the parse transform `ex_unit_erlang_transform`. The
parse transform does the following for each test module:

1. Collects the `*_test` functions and the `-async`, `-moduletag` and `-tag`
   attributes.
2. Generates and exports `__ex_unit__/0` and `__ex_unit__/2`. ExUnit calls
   these two functions on a test module.
3. Generates a `name_test/1` function for each test with arity 0. ExUnit calls
   a test with the context as the only argument.
4. Encloses the body of each test in a `try` expression. The `catch` clause
   converts an error from an OTP assert macro into an
   `ExUnit.AssertionError`. The `try` expression also keeps the test function
   in the stacktrace, which ExUnit uses to print the failing source line.

`ExUnitErlang.start/0` connects the test modules to `mix test`:

1. Mix loads each selected test file with the Elixir compiler. The Elixir
   compiler cannot compile an Erlang file.
2. Mix does not load a file that the Elixir code server reports as already
   required. Mix waits for a file that another process is loading.
3. `ExUnitErlang.start/0` registers every Erlang source file of the
   application with the Elixir code server as a file that is being loaded.
4. When Mix requests one of these files, `ex_unit_erlang` registers the test
   module of the file with ExUnit. `ex_unit_erlang` then marks the file as
   required, and Mix continues without compiling the file.

`ex_unit_erlang` registers exactly the Erlang files that Mix selects. File
paths, line numbers, `--failed` and `--partitions` therefore need no separate
implementation.

### Registration without the code server

`ExUnitErlang.start/0` depends on internal behaviour of the Elixir code
server. `ExUnitErlang.start/0` verifies this behaviour at startup and raises
an error when the behaviour is different.

`ExUnitErlang.register/0` is an alternative that does not use the code server.
To use `ExUnitErlang.register/0`:

1. Remove `ExUnitErlang.start()` from `test/test_helper.exs`.
2. Remove `test_pattern` and `test_load_filters` from `mix.exs`.
3. Add a file `test/erlang_test.exs` with the following content:

   ```elixir
   ExUnitErlang.register()
   ```

With `ExUnitErlang.register/0`, loading `test/erlang_test.exs` runs every
Erlang test module. Selection by Erlang file path and `mix test --failed` do
not work. The following commands select Erlang tests instead:

- `mix test --only module:session_tests`
- `mix test --only location:test/session_tests.erl:12`

## Features

### Implemented

| Feature | Erlang interface |
| --- | --- |
| Tests | `*_test/0` and `*_test/1` functions |
| Test context | A map, passed to tests and callbacks with arity 1 |
| Assertions | OTP assert macros, reported as ExUnit assertion failures with the source line and the assert comment |
| Diff on failure | `?assertEqual` |
| Callbacks | `setup_all/0`, `setup_all/1`, `setup/0`, `setup/1` |
| Teardown | `ex_unit_erlang:on_exit/1`, `ex_unit_erlang:on_exit/2` |
| Supervised processes | `ex_unit_erlang:start_supervised/1`, `ex_unit_erlang:start_supervised/2`, `ex_unit_erlang:stop_supervised/1` |
| Async modules | `-async(true).` |
| Tags | `-moduletag` and `-tag` |
| ExUnit tags | `skip`, `timeout`, `tmp_dir`, `capture_log` |
| Filters | `--only` and `--exclude` by tag, module, test name and `location:FILE:LINE` |
| Compile-time validation | Attributes, test names and callbacks |
| Test module discovery | `ExUnitErlang.start/0` |
| Selection by file | `mix test FILE.erl` and `mix test FILE.erl:LINE`, also combined with Elixir test files |
| Rerun of failed tests | `mix test --failed` |
| Partitioned runs | `mix test --partitions` |

### Planned

- `mix test --stale` that tracks the modules that an Erlang test calls.
- `describe` blocks, `describetag`, and `setup` per `describe` block.
- More than one `setup` or `setup_all` callback per module.
- The module options `group` and `parameterize`.
- `capture_io` and `capture_log` functions for Erlang.
- `start_link_supervised`.
- Diff terms in Erlang syntax.
- A diff for `?assertMatch` and `?assertNotEqual`.
- Macros for message assertions (`assert_receive`, `refute_receive`).
- Doctests.
- Automatic exclusion of test modules from `mix test --cover` reports.
- Support for Elixir versions before 1.19.

## Limitations

- `ex_unit_erlang` registers test modules with `ExUnit.Server.add_module/2`.
  `ExUnit.Server` is a private module of ExUnit. `use ExUnit.Case` makes the
  same call. The function can change between Elixir releases.
- `ExUnitErlang.start/0` uses `:elixir_code_server`, a private module of
  Elixir. `ExUnitErlang.start/0` reads the state of the code server every
  2 ms while Mix loads test files.
- `mix test --stale` reruns an Erlang test file after the test file changes.
  `mix test --stale` does not rerun an Erlang test file after a module that
  the test calls changes.
- Mix fails with an Elixir syntax error when Mix loads an `.erl` file under
  `test/` that is not compiled into the application. An example is a data
  file outside `erlc_paths`. The setting `:test_ignore_filters` excludes such
  a file.
- Mix compiles the test modules into the `ebin` directory of the application
  in the test environment.
- A module cannot define the same test name or callback name with both arity
  0 and arity 1. ExUnit identifies a test by name only.
- ExUnit prints the terms of a `?assertEqual` diff in Elixir syntax.

## Verification

`mix test` runs the test suite of the library.

- The test suite runs `mix test` in the fixture project
  `test/fixtures/sample`. The fixture project uses the library as an
  application does. The test suite checks the output and the exit status of
  each run.
- The fixture modules with the tag `failing` fail deliberately. The test
  suite checks the failure reports.
- The test suite compiles the fixture project once. The `mix test` runs then
  execute concurrently.
- `mix lint` checks formatting, unused dependencies, Dialyzer and the
  documentation build.

CI runs `mix lint` and `mix test` on every push to `main` and on every pull
request.

| Elixir | Erlang/OTP | CI job |
| --- | --- | --- |
| 1.19 | 28 | Test |
| 1.20 | 28 | Lint, Test |

The test suite passes locally on the following versions:

| Elixir | Erlang/OTP | Result |
| --- | --- | --- |
| 1.19.5 | 27.3.4 | 21 of 21 tests pass |
| 1.19.4 | 28.3 | 21 of 21 tests pass |
| 1.20.1 | 28.3 | 21 of 21 tests pass |

## Source layout

| Path | Content |
| --- | --- |
| `include/ex_unit.hrl` | The header file that a test module includes. |
| `src/ex_unit_erlang_transform.erl` | The parse transform. |
| `src/ex_unit_erlang.erl` | The functions that a test calls: `on_exit`, `start_supervised`, `stop_supervised`. |
| `lib/ex_unit_erlang.ex` | `ExUnitErlang.start/0` and `ExUnitErlang.register/1`. |
| `lib/ex_unit_erlang/loader.ex` | The integration with Mix and the Elixir code server. |
| `lib/ex_unit_erlang/adapter.ex` | The conversion of a test module to the ExUnit structures, and the callback handling. |
| `lib/ex_unit_erlang/assertion.ex` | The conversion of OTP assert errors to `ExUnit.AssertionError`. |
| `test/fixtures/sample` | The fixture project that the test suite runs. |

## License

Apache License 2.0. See [LICENSE.md](LICENSE.md).
