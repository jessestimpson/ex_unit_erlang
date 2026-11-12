%% Header file for ExUnit test modules written in Erlang.
%%
%% Example:
%%
%%   -module(my_tests).
%%   -include_lib("ex_unit_erlang/include/ex_unit.hrl").
%%
%%   add_test() ->
%%       ?assertEqual(4, 2 + 2).
%%
%% Effects of including the header file:
%%
%%   * The OTP assert macros of stdlib/include/assert.hrl are defined.
%%   * Every `*_test/0` and `*_test/1` function becomes an ExUnit test.
%%   * The module exports the functions that ExUnit requires of a test
%%     module.
%%
%% Supported attributes: -async, -moduletag, -tag.
%% Supported callbacks: setup_all/0, setup_all/1, setup/0, setup/1.
%%
%% The README describes the attributes and the callbacks.

-ifndef(EX_UNIT_HRL).
-define(EX_UNIT_HRL, true).

-include_lib("stdlib/include/assert.hrl").

-compile({parse_transform, ex_unit_erlang_transform}).

-endif.
