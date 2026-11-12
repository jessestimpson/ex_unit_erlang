-module(callbacks_tests).
-include_lib("ex_unit_erlang/include/ex_unit.hrl").

-moduletag(callbacks).
-moduletag({owner, core}).

setup_all() ->
    Table = ets:new(?MODULE, [public]),
    ex_unit_erlang:on_exit(fun() -> ok end),
    {ok, #{table => Table}}.

setup(#{table := Table, test := Test}) ->
    ets:insert(Table, {Test, started}),
    Parent = self(),
    ex_unit_erlang:on_exit(fun() -> Parent ! done end),
    [{greeting, <<"hello">>}].

setup_all_test(#{table := Table}) ->
    ?assertEqual([{setup_all_test, started}], ets:lookup(Table, setup_all_test)).

setup_test(#{greeting := Greeting}) ->
    ?assertEqual(<<"hello">>, Greeting).

moduletag_test(#{callbacks := true, owner := Owner}) ->
    ?assertEqual(core, Owner).

-tag(slow).
-tag({retries, 3}).
tag_test(#{slow := Slow, retries := Retries, owner := core}) ->
    ?assert(Slow),
    ?assertEqual(3, Retries).

-tag([{owner, other}, fast]).
tag_overrides_moduletag_test(#{owner := Owner, fast := true}) ->
    ?assertEqual(other, Owner).

untagged_test(Context) ->
    ?assertNot(maps:is_key(slow, Context)).

-tag(tmp_dir).
tmp_dir_test(#{tmp_dir := Dir}) ->
    ?assert(filelib:is_dir(Dir)).

-tag(skip).
skipped_test() ->
    error(never_runs).

start_supervised_test() ->
    Spec = #{id => agent, start => {'Elixir.Agent', start_link, [fun() -> 0 end]}},
    {ok, Pid} = ex_unit_erlang:start_supervised(Spec),
    ?assert(is_process_alive(Pid)),
    ?assertEqual(ok, ex_unit_erlang:stop_supervised(agent)).
