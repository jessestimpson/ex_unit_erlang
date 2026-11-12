defmodule ExUnitErlang.Loader do
  @moduledoc false
  # Connects Erlang test modules to the file selection of `mix test`.
  #
  # Background:
  #
  #   * Mix loads each selected test file with the Elixir compiler. The Elixir
  #     compiler cannot compile an .erl file.
  #   * Mix does not load a file that the Elixir code server reports as
  #     already required.
  #   * Mix waits for a file that another process is loading.
  #
  # Procedure:
  #
  #   1. start/1 registers every Erlang source file of the application with
  #      the code server as a file that is being loaded.
  #   2. A Mix worker that requests one of the files waits in the code server.
  #   3. The watcher process detects the waiting worker.
  #   4. The watcher registers the module with ExUnit when the module is a
  #      test module.
  #   5. The watcher marks the file as required. The Mix worker continues
  #      without compiling the file.
  #
  # Result: the registered Erlang test modules are exactly the modules of the
  # files that Mix selects. File paths, FILE:LINE, --failed and --partitions
  # have the same effect as for Elixir test files.
  #
  # Dependency: the procedure uses the acquire and required messages of
  # :elixir_code_server and the layout of the server state. start/1 verifies
  # both and raises an error when either is different. Without the check, a
  # change in the code server would block `mix test` indefinitely.

  @poll_interval 2

  def start(app) do
    if Process.whereis(__MODULE__) do
      :ok
    else
      if !Process.whereis(ExUnit.Server) do
        raise "ExUnit is not running. Call ExUnit.start() before ExUnitErlang.start()"
      end

      check_code_server!()
      modules = erlang_modules(app)
      warn_unloadable(for {file, module, true} <- modules, do: {file, module})

      pending =
        for {file, module, test?} <- modules,
            :elixir_code_server.call({:acquire, file}) == :proceed,
            into: %{} do
          {file, {module, test?}}
        end

      pid = spawn(fn -> watch(pending) end)
      Process.register(pid, __MODULE__)
      :ok
    end
  end

  ## Watcher

  defp watch(pending) when map_size(pending) == 0, do: :ok

  defp watch(pending) do
    required = required_files()

    requested =
      for {file, entry} <- pending, match?([_ | _], Map.get(required, file)), do: {file, entry}

    for {file, {module, test?}} <- requested do
      if test?, do: register(module)
      :elixir_code_server.cast({:required, file})
    end

    Process.sleep(@poll_interval)
    watch(Map.drop(pending, Enum.map(requested, &elem(&1, 0))))
  end

  defp register(module) do
    ExUnitErlang.register([module])
  catch
    kind, reason ->
      # An exception in the watcher would leave the Mix worker waiting
      # indefinitely. The watcher prints the error and stops the VM.
      IO.puts(:stderr, [
        "ex_unit_erlang: could not register #{module}\n",
        Exception.format(kind, reason, __STACKTRACE__)
      ])

      System.halt(1)
  end

  ## Code server

  defp required_files do
    elem(:sys.get_state(:elixir_code_server), 1)
  end

  defp check_code_server! do
    probe = "ex_unit_erlang probe #{System.unique_integer([:positive])}"

    supported? =
      try do
        :proceed = :elixir_code_server.call({:acquire, probe})
        claimed? = match?(%{^probe => []}, required_files())
        :elixir_code_server.cast({:required, probe})
        :required = :elixir_code_server.call({:acquire, probe})
        :elixir_code_server.cast({:unrequire_files, [probe]})
        claimed?
      catch
        _, _ -> false
      end

    if !supported? do
      raise """
      ExUnitErlang.start/0 does not support Elixir #{System.version()}.

      ExUnitErlang.start/0 depends on internal behaviour of the Elixir code \
      server. The behaviour of this Elixir version is different. To run the \
      Erlang tests, remove ExUnitErlang.start() and add a file \
      test/erlang_test.exs with the following content:

          ExUnitErlang.register()
      """
    end
  end

  ## Discovery

  # Returns {source_file, module, test_module?} for each Erlang module of the
  # application.
  defp erlang_modules(app) do
    for module <- ExUnitErlang.app_modules(app),
        Code.ensure_loaded?(module),
        file = source(module),
        Path.extname(file) == ".erl" do
      {file, module, ExUnitErlang.test_module?(module)}
    end
  end

  defp source(module) do
    case module.module_info(:compile)[:source] do
      source when is_list(source) -> List.to_string(source)
      _ -> nil
    end
  end

  # Prints a warning for each test module that Mix will not load. Without
  # the warning, the tests of the module do not run and no error is reported.
  defp warn_unloadable(test_modules) do
    config = Mix.Project.config()
    pattern = config[:test_pattern] || "*.{ex,exs}"
    filters = config[:test_load_filters] || [&String.ends_with?(&1, "_test.exs")]

    candidates =
      for path <- config[:test_paths] || ["test"],
          file <- Path.wildcard("#{path}/**/#{pattern}"),
          matches?(file, filters),
          into: MapSet.new(),
          do: Path.expand(file)

    case for {file, _} <- test_modules, file not in candidates, do: Path.relative_to_cwd(file) do
      [] ->
        :ok

      missed ->
        IO.puts(:stderr, """
        warning: ex_unit_erlang found Erlang test modules that "mix test" will not load:

        #{Enum.map_join(missed, "\n", &("    " <> &1))}

        Put the files under a test path and add the following settings to mix.exs:

            test_pattern: "*.{ex,exs,erl}",
            test_load_filters: [~r/_test\\.exs$/, ~r/\\.erl$/]
        """)
    end
  end

  defp matches?(file, filters) do
    Enum.any?(filters, fn
      %Regex{} = regex -> Regex.match?(regex, file)
      binary when is_binary(binary) -> file == binary
      fun when is_function(fun, 1) -> fun.(file)
    end)
  end
end
