defmodule ExUnitErlang do
  @moduledoc """
  `ExUnitErlang` runs test modules written in Erlang under ExUnit.

  ## Example

  A test module is an Erlang module that includes the header file
  `ex_unit_erlang/include/ex_unit.hrl`:

      -module(my_tests).
      -include_lib("ex_unit_erlang/include/ex_unit.hrl").

      add_test() ->
          ?assertEqual(4, 2 + 2).

  ## Configuration

  Mix compiles the test modules with the other Erlang code of the project.
  Two steps connect the test modules to `mix test`:

  1. Call `start/0` in `test/test_helper.exs`, after `ExUnit.start/0`:

         ExUnit.start()
         ExUnitErlang.start()

  2. Add the following settings to the project configuration in `mix.exs`:

         erlc_paths: ["src", "test"],
         test_pattern: "*.{ex,exs,erl}",
         test_load_filters: [~r/_test\\.exs$/, ~r/\\.erl$/]

  The README describes the test module format, the callbacks and the
  attributes.
  """

  @doc """
  Connects the Erlang test modules of `app` to `mix test`.

  Call `start/1` in `test/test_helper.exs`, after `ExUnit.start/1`. The
  default value of `app` is the application of the current Mix project.

  `start/1` registers an Erlang test module with ExUnit when Mix selects the
  source file of the test module. `start/1` does not register a test module
  that Mix does not select. The following commands therefore have the same
  effect on Erlang test files as on Elixir test files:

    * `mix test`
    * `mix test test/my_tests.erl`
    * `mix test test/my_tests.erl:12`
    * `mix test --failed`
    * `mix test --partitions N`

  ## Requirements

    * The settings `:test_pattern` and `:test_load_filters` in `mix.exs` must
      match the Erlang test files. The module documentation shows the
      settings. `start/1` prints a warning when Mix will not load a test
      module.
    * ExUnit must be running.

  ## Limitations

    * `start/1` depends on internal behaviour of the Elixir code server.
      `start/1` verifies the behaviour and raises a `RuntimeError` when the
      behaviour is different. `register/1` does not depend on the code server.
  """
  @spec start(atom) :: :ok
  def start(app \\ Mix.Project.config()[:app]) when is_atom(app) do
    ExUnitErlang.Loader.start(app)
  end

  @doc """
  Registers Erlang test modules with ExUnit.

  `start/1` is the recommended function. `register/1` is the alternative that
  does not depend on the Elixir code server.

  `register/1` adds the test modules to the test run unconditionally. The
  files given to `mix test` do not affect `register/1`.

  Call `register/1` in a test file, such as `test/erlang_test.exs`. Mix
  reports test results only when Mix loads at least one test file.

  ## Arguments

    * `register()` registers every Erlang test module of the current Mix
      project.
    * `register(app)` registers every Erlang test module of the application
      `app`.
    * `register(modules)` registers the modules in the list `modules`.

  ## Return value

  `register/1` returns the list of registered modules.
  """
  @spec register(atom | [module]) :: [module]
  def register(app_or_modules \\ Mix.Project.config()[:app])

  def register(modules) when is_list(modules) do
    for module <- modules do
      if not test_module?(module) do
        raise ArgumentError,
              "#{inspect(module)} is not an ex_unit_erlang test module. " <>
                "Does it include \"ex_unit_erlang/include/ex_unit.hrl\"?"
      end

      add(module)
    end
  end

  def register(app) when is_atom(app) do
    for module <- app_modules(app), test_module?(module) do
      add(module)
    end
  end

  @doc false
  def app_modules(app) do
    case Application.load(app) do
      :ok ->
        :ok

      {:error, {:already_loaded, ^app}} ->
        :ok

      {:error, reason} ->
        raise ArgumentError, "could not load application #{app}: #{inspect(reason)}"
    end

    Enum.sort(Application.spec(app, :modules))
  end

  @doc false
  def test_module?(module) do
    Code.ensure_loaded?(module) and function_exported?(module, :__ex_unit_erlang__, 0)
  end

  defp add(module) do
    %{async: async?} = module.__ex_unit_erlang__()
    ExUnit.Server.add_module(module, %{async?: async?, group: nil, parameterize: nil})
    module
  end
end
