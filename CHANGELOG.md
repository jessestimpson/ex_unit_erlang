# Changelog

## 0.1.0

Initial release.

### Features

- An Erlang module becomes an ExUnit test module when the module includes
  `ex_unit_erlang/include/ex_unit.hrl`.
- A `*_test/0` or `*_test/1` function is a test. A test with arity 1 receives
  the ExUnit context.
- ExUnit reports a failed OTP assert macro as an assertion failure.
- The callbacks `setup_all` and `setup` are supported.
- `ex_unit_erlang:on_exit/1`, `ex_unit_erlang:on_exit/2`,
  `ex_unit_erlang:start_supervised/1`, `ex_unit_erlang:start_supervised/2`
  and `ex_unit_erlang:stop_supervised/1` are available to tests.
- The attributes `-async`, `-moduletag` and `-tag` are supported.
- `ExUnitErlang.start/0` connects Erlang test files to `mix test`. Selection
  by file, selection by `FILE:LINE`, `--failed` and `--partitions` are
  supported.
