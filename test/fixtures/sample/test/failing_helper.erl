-module(failing_helper).
-include_lib("stdlib/include/assert.hrl").
-export([check/1]).

check(N) ->
    ?assert(N > 10),
    ok.
