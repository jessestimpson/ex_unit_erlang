defmodule ExUnitErlang.Adapter do
  @moduledoc false
  # The functions that the generated code of a test module calls at run time.
  #
  # The parse transform `:ex_unit_erlang_transform` generates the calls. This
  # module converts the description of a test module into the ExUnit
  # structures, runs the callbacks, and converts the assertion errors.

  @reserved [:module, :file, :line, :test, :async, :registered, :describe]

  @doc """
  Builds the `ExUnit.TestModule` for an Erlang test module.
  """
  def test_module(module) do
    spec = module.__ex_unit_erlang__()
    file = source(module)
    moduletags = normalize_tags(spec.moduletags)

    tests =
      for {name, line, tags} <- spec.tests do
        tags =
          moduletags
          |> Map.merge(normalize_tags(tags))
          |> Map.merge(%{
            line: line,
            file: file,
            registered: %{},
            describe: nil,
            describe_line: nil,
            test_type: :test
          })

        # ExUnit 1.20 added the field `description`. struct/2 ignores the
        # field on ExUnit 1.19.
        struct(ExUnit.Test,
          name: name,
          description: Atom.to_string(name),
          case: module,
          module: module,
          tags: tags
        )
      end

    %ExUnit.TestModule{
      file: file,
      name: module,
      setup_all?: spec.setup_all,
      tags: moduletags,
      tests: tests
    }
  end

  @doc """
  Runs a `setup` or `setup_all` callback.

  Returns the context merged with the return value of the callback.
  """
  def callback(module, kind, fun, context) do
    result =
      try do
        if is_function(fun, 0), do: fun.(), else: fun.(context)
      catch
        class, reason -> reraise(module, class, reason, __STACKTRACE__)
      end

    merge(module, kind, context, result)
  end

  @doc """
  Raises again an exception that a test raised.

  An error from an OTP assert macro is converted to an
  `ExUnit.AssertionError`. Every other exception is raised unchanged. The
  stacktrace is preserved.
  """
  def reraise(module, :error, {name, info} = reason, stacktrace)
      when is_atom(name) and is_list(info) do
    case ExUnitErlang.Assertion.translate(name, info, module) do
      {:ok, exception} -> :erlang.raise(:error, exception, stacktrace)
      :error -> :erlang.raise(:error, reason, stacktrace)
    end
  end

  def reraise(_module, class, reason, stacktrace) do
    :erlang.raise(class, reason, stacktrace)
  end

  ## Helpers

  defp source(module) do
    case module.module_info(:compile)[:source] do
      source when is_list(source) -> List.to_string(source)
      _ -> "nofile"
    end
  end

  defp normalize_tags(tags) do
    tags
    |> List.flatten()
    |> Enum.reduce(%{}, fn
      tag, acc when is_atom(tag) -> Map.put(acc, tag, true)
      {key, value}, acc -> Map.put(acc, key, value)
      map, acc when is_map(map) -> Map.merge(acc, map)
    end)
  end

  defp merge(_module, _kind, context, :ok), do: context
  defp merge(module, kind, context, {:ok, data}), do: merge_data(module, kind, context, data)
  defp merge(module, kind, context, data), do: merge_data(module, kind, context, data)

  defp merge_data(module, kind, context, data) when is_map(data) and not is_struct(data) do
    Map.merge(context, data, fn
      key, old, new when key in @reserved and old != new ->
        raise "#{kind} in #{module} tried to overwrite the reserved context key " <>
                "#{format(key)}, which is set by ExUnit"

      _key, _old, new ->
        new
    end)
  end

  defp merge_data(module, kind, context, data) when is_list(data) do
    if Enum.all?(data, &match?({_, _}, &1)) do
      merge_data(module, kind, context, Map.new(data))
    else
      bad_return(module, kind, data)
    end
  end

  defp merge_data(module, kind, _context, data), do: bad_return(module, kind, data)

  defp bad_return(module, kind, value) do
    raise "expected #{kind} in #{module} to return ok, {ok, Context}, or Context, " <>
            "where Context is a map or a proplist, got: #{format(value)}"
  end

  defp format(term), do: IO.iodata_to_binary(:io_lib.format(~c"~tp", [term]))
end
