defmodule Sample.MixProject do
  use Mix.Project

  def project do
    [
      app: :sample,
      version: "0.1.0",
      elixir: "~> 1.19",
      erlc_paths: erlc_paths(Mix.env()),
      test_pattern: "*.{ex,exs,erl}",
      test_load_filters: [~r/_test\.exs$/, ~r/\.erl$/],
      deps: [{:ex_unit_erlang, path: "../../..", only: :test}]
    ]
  end

  def application, do: []

  defp erlc_paths(:test), do: ["src", "test"]
  defp erlc_paths(_), do: ["src"]
end
