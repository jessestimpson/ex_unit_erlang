defmodule ExUnitErlang.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/jessestimpson/ex_unit_erlang"

  def project do
    [
      app: :ex_unit_erlang,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      description: description(),
      package: package(),
      docs: docs(),
      dialyzer: [plt_add_apps: [:mix, :ex_unit]],
      # test/fixtures contains a complete Mix project with test files. The
      # test files of the fixture project are not test files of the library.
      test_load_filters: [&(Path.dirname(&1) == "test" and String.ends_with?(&1, "_test.exs"))],
      test_ignore_filters: [&String.starts_with?(&1, "test/fixtures/")]
    ]
  end

  def application do
    [
      extra_applications: [:ex_unit]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:dialyxir, "~> 1.4", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      lint: [
        "format --check-formatted",
        "deps.unlock --check-unused",
        "dialyzer",
        "docs --warnings-as-errors"
      ]
    ]
  end

  defp description do
    "Runs test modules written in Erlang under ExUnit."
  end

  defp package do
    [
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url},
      # The default file list of Hex does not contain `include`. `include`
      # contains the header file that every Erlang test module includes.
      files: ~w(lib src include mix.exs .formatter.exs README.md LICENSE.md CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md", "LICENSE.md"],
      source_url: @source_url,
      source_ref: "v#{@version}",
      # ExUnit.Server is a private module of ExUnit. The README names the
      # module in the "Limitations" section.
      skip_code_autolink_to: ["ExUnit.Server", "ExUnit.Server.add_module/2"]
    ]
  end
end
