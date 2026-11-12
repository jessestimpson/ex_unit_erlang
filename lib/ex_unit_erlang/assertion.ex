defmodule ExUnitErlang.Assertion do
  @moduledoc false
  # Converts the errors of the OTP assert macros to ExUnit.AssertionError.
  #
  # The OTP assert macros are defined in stdlib/include/assert.hrl. EUnit uses
  # the same macros. A failed macro raises `error({MacroName, Info})`. `Info`
  # is a proplist, for example:
  #
  #     [{module, M}, {line, L}, {expression, "..."}, {expected, E}, {value, V}]

  # The keys with a value that is source text. The other values are terms.
  @text_keys [:expression, :pattern]
  @hidden_keys [:module, :line, :comment]

  @doc """
  Returns `{:ok, exception}` if `{name, info}` is an assert macro failure.
  """
  def translate(name, info, test_module) do
    if assertion?(name, info) do
      {:ok, build(name, Map.new(info), info, test_module)}
    else
      :error
    end
  end

  defp assertion?(name, info) do
    match?("assert" <> _, Atom.to_string(name)) and
      Enum.all?(info, &match?({key, _} when is_atom(key), &1)) and
      Keyword.has_key?(info, :module) and Keyword.has_key?(info, :line)
  end

  # ExUnit prints a diff when the exception has a `left` and a `right` field.
  defp build(:assertEqual, %{expected: expected, value: value} = map, _info, _test_module) do
    %ExUnit.AssertionError{
      message: headline(:assertEqual, map) <> "\nleft is the expected term, right is the value",
      left: expected,
      right: value,
      context: :==
    }
  end

  defp build(name, map, info, test_module) do
    details =
      for {key, value} <- info,
          key not in @hidden_keys,
          # ExUnit prints the source line when the assertion is in the test
          # module. The expression is then redundant.
          not (key == :expression and map.module == test_module) do
        detail(key, value)
      end

    %ExUnit.AssertionError{message: Enum.join([headline(name, map) | details], "\n")}
  end

  defp headline(name, map) do
    location =
      case map do
        %{module: module, line: line} -> " (#{module}, line #{line})"
        _ -> ""
      end

    comment =
      case map do
        %{comment: comment} -> ": " <> text(comment)
        _ -> ""
      end

    "?#{name} failed#{location}#{comment}"
  end

  defp detail(key, value) when key in @text_keys, do: "#{key}: #{text(value)}"

  defp detail(:unexpected_exception, {class, reason, stacktrace}) do
    "unexpected_exception: #{term(class)}:#{term(reason)}\n" <>
      Exception.format_stacktrace(stacktrace)
  end

  defp detail(key, value), do: "#{key}: #{term(value)}"

  # The preprocessor separates the tokens of macro source text with spaces,
  # for example "foo : bar ( 1 )". This function removes the spaces around
  # punctuation.
  defp text(value) do
    if :io_lib.deep_char_list(value) or is_binary(value) do
      value
      |> IO.chardata_to_string()
      |> String.replace(~r/\s+([,;:\)\]\}\(])/, "\\1")
      |> String.replace(~r/([:\(\[\{])\s+/, "\\1")
    else
      term(value)
    end
  rescue
    _ -> term(value)
  end

  # Formats a term in Erlang syntax.
  defp term(value), do: IO.iodata_to_binary(:io_lib.format(~c"~tp", [value]))
end
