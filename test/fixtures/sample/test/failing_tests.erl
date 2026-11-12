%% Every test in this module fails deliberately. The test suite of
%% ex_unit_erlang checks the failure reports.
-module(failing_tests).
-include_lib("ex_unit_erlang/include/ex_unit.hrl").

-moduletag(failing).

equal_test() ->
    ?assertEqual({ok, [x, y]}, {ok, [x, id(z)]}).

match_test() ->
    ?assertMatch({ok, _}, sample_math:divide(1, 0)).

assert_test() ->
    ?assert(sample_math:add(1, 1) =:= 3).

comment_test() ->
    ?assertEqual(1, id(2), "one is not two").

exception_test() ->
    ?assertError(badarg, sample_math:add(1, 1)).

helper_test() ->
    failing_helper:check(5).

badmatch_test() ->
    {ok, _} = sample_math:divide(1, 0).

exit_test() ->
    exit(boom).

-tag({timeout, 50}).
timeout_test() ->
    timer:sleep(5000).

id(X) -> X.
