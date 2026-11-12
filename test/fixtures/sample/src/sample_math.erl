-module(sample_math).
-export([add/2, divide/2]).

add(A, B) -> A + B.

divide(_, 0) -> {error, division_by_zero};
divide(A, B) -> {ok, A / B}.
