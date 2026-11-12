-module(ex_unit_erlang).
-moduledoc """
Functions for ExUnit tests written in Erlang.

Each function calls the function of the same name in `ExUnit.Callbacks`. A
test calls `ex_unit_erlang:on_exit(Fun)` instead of
`'Elixir.ExUnit.Callbacks':on_exit(Fun)`.
""".

-export([
    on_exit/1,
    on_exit/2,
    start_supervised/1,
    start_supervised/2,
    stop_supervised/1
]).

-doc """
Registers `Fun` to run after the current test finishes.

When a `setup_all` callback calls `on_exit/1`, `Fun` runs after all tests of
the module finish.

`Fun` runs in a separate process. `Fun` runs whether the test passes or fails.
""".
-spec on_exit(fun(() -> term())) -> ok.
on_exit(Fun) when is_function(Fun, 0) ->
    'Elixir.ExUnit.Callbacks':on_exit(Fun).

-doc """
Registers `Fun` under `Name` to run after the current test finishes.

A second call with the same `Name` replaces the first `Fun`. In all other
respects, `on_exit/2` is the same as `on_exit/1`.
""".
-spec on_exit(term(), fun(() -> term())) -> ok.
on_exit(Name, Fun) when is_function(Fun, 0) ->
    'Elixir.ExUnit.Callbacks':on_exit(Name, Fun).

-doc """
Starts a child process under the test supervisor.

ExUnit stops the child process before the next test starts.

`ChildSpec` is a child spec map, a module, or a `{Module, Arg}` tuple.
""".
-spec start_supervised(supervisor:child_spec() | module() | {module(), term()}) ->
    {ok, pid()} | {ok, pid(), term()} | {error, term()}.
start_supervised(ChildSpec) ->
    'Elixir.ExUnit.Callbacks':start_supervised(ChildSpec).

-doc """
Starts a child process under the test supervisor, with overrides.

`Opts` is a proplist of child spec fields that override the fields of
`ChildSpec`. Example: `[{id, my_id}, {restart, temporary}]`.

In all other respects, `start_supervised/2` is the same as
`start_supervised/1`.
""".
-spec start_supervised(supervisor:child_spec() | module() | {module(), term()}, [{atom(), term()}]) ->
    {ok, pid()} | {ok, pid(), term()} | {error, term()}.
start_supervised(ChildSpec, Opts) ->
    'Elixir.ExUnit.Callbacks':start_supervised(ChildSpec, Opts).

-doc """
Stops a child process that `start_supervised/1` or `start_supervised/2`
started.

`Id` is the child id of the child spec.
""".
-spec stop_supervised(term()) -> ok | {error, not_found}.
stop_supervised(Id) ->
    'Elixir.ExUnit.Callbacks':stop_supervised(Id).
