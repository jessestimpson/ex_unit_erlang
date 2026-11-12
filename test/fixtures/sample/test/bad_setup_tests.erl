-module(bad_setup_tests).
-include_lib("ex_unit_erlang/include/ex_unit.hrl").

-moduletag(failing).

setup() ->
    not_a_context.

never_runs_test() ->
    ok.
