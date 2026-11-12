-module(bad_tests).
-include_lib("ex_unit_erlang/include/ex_unit.hrl").
-async(maybe_later).
-moduletag({line, 3}).

-tag("nope").
a_test() -> ok.
a_test(_) -> ok.

-tag(slow).
helper() -> ok.

setup() -> ok.
setup(_) -> ok.
