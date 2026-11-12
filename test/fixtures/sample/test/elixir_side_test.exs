defmodule ElixirSideTest do
  use ExUnit.Case, async: true

  test "elixir one" do
    assert :sample_math.add(1, 2) == 3
  end

  test "elixir two" do
    assert :sample_math.add(2, 2) == 4
  end
end
