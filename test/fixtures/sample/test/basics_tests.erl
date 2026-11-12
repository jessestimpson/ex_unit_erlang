-module(basics_tests).
-include_lib("ex_unit_erlang/include/ex_unit.hrl").

-async(true).

add_test() ->
    ?assertEqual(4, sample_math:add(2, 2)).

divide_test() ->
    ?assertMatch({ok, _}, sample_math:divide(1, 2)),
    ?assertEqual({error, division_by_zero}, sample_math:divide(1, 0)).

%% A test with arity 1 receives the ExUnit context. The context is a map.
context_test(#{module := Module, test := Test, async := Async}) ->
    ?assertEqual(?MODULE, Module),
    ?assertEqual(context_test, Test),
    ?assert(Async).

multiple_clauses_test(#{line := Line}) when Line < 0 ->
    error(unreachable);
multiple_clauses_test(#{file := File}) ->
    ?assertEqual(<<"basics_tests.erl">>, filename:basename(File)).

exception_test() ->
    ?assertError(badarith, 1 / zero()),
    ?assertThrow(oops, throw(oops)),
    ?assertExit(normal, exit(normal)).

%% zero/0 is not a test. The name does not end in _test.
zero() -> 0.
