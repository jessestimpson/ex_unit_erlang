defmodule ExUnitErlangTest do
  # The tests run `mix test` in the fixture project test/fixtures/sample. The
  # fixture project uses the library as an application does. The tests check
  # the output and the exit status of each run.
  use ExUnit.Case, async: true

  @moduletag timeout: 180_000
  @sample Path.expand("fixtures/sample", __DIR__)

  # The `mix test` runs that the tests examine. One run takes several
  # seconds, mostly for the start of mix. setup_all starts all runs
  # concurrently.
  @runs [
    passing: {["--exclude", "failing", "--trace"], []},
    failing: {["--only", "failing"], []},
    erl_file: {["test/basics_tests.erl"], []},
    file_line: {["test/callbacks_tests.erl:30", "--trace"], []},
    mixed: {["test/basics_tests.erl:7", "test/elixir_side_test.exs:8"], []},
    elixir_file: {["test/elixir_side_test.exs"], []},
    helper_file: {["test/failing_helper.erl"], []},
    only_tag: {["--only", "slow"], []},
    only_module: {["--only", "module:basics_tests"], []},
    only_test: {["--only", "test:add_test"], []},
    # tmp_dir_test uses a fixed directory. Only one concurrent run can
    # include tmp_dir_test. The run `passing` includes tmp_dir_test.
    partition_1:
      {["--partitions", "2", "--exclude", "failing", "--exclude", "tmp_dir"], partition: "1"},
    partition_2:
      {["--partitions", "2", "--exclude", "failing", "--exclude", "tmp_dir"], partition: "2"},
    # --failed reads the failures that the previous run recorded in the
    # build directory. The two runs execute in sequence, in a separate build
    # directory.
    failed: {[["test/failing_tests.erl"], ["--failed"]], build: "_build_failed"}
  ]

  setup_all do
    # The fixture project is compiled once. The runs then skip compilation,
    # the dependency check and the build directory lock. Each of the three
    # would make concurrent runs wait for each other.
    {_, 0} = mix(["compile"], [])
    File.rm_rf!(Path.join(@sample, "_build_failed"))
    {_, 0} = System.cmd("cp", ["-R", "_build", "_build_failed"], cd: @sample)
    # Remove the failures that a previous execution of the test suite recorded.
    File.rm(Path.join(@sample, "_build_failed/test/lib/sample/.mix/.mix_test_failures"))

    @runs
    |> Task.async_stream(
      fn
        {name, {[[_ | _] | _] = sequence, opts}} ->
          {name, Enum.map(sequence, &mix_test(&1, opts))}

        {name, {args, opts}} ->
          {name, mix_test(args, opts)}
      end,
      timeout: :infinity,
      max_concurrency: length(@runs)
    )
    |> Map.new(fn {:ok, result} -> result end)
  end

  defp mix_test(args, opts) do
    mix(["test", "--seed", "0", "--no-compile", "--no-deps-check" | args], opts)
  end

  # Returns the test counts of a `mix test` run.
  #
  # The format of the summary depends on the Elixir version:
  #
  #   * Elixir 1.19: "16 tests, 0 failures, 1 skipped (10 excluded)"
  #   * Elixir 1.20: "Result: 15 passed, 1 skipped, 10 excluded", or
  #     "Result: 0/10 passed, 16 excluded" followed by "Failed: 10 tests"
  defp summary(output) do
    count = fn regex ->
      case Regex.run(regex, output) do
        [_, n] -> String.to_integer(n)
        nil -> 0
      end
    end

    skipped = count.(~r/(\d+) skipped/)
    excluded = count.(~r/(\d+) excluded/)

    case Regex.run(~r/(\d+) tests?, (\d+) failures?/, output) do
      [_, tests, failures] ->
        failed = String.to_integer(failures)
        passed = String.to_integer(tests) - failed - skipped
        %{passed: passed, failed: failed, skipped: skipped, excluded: excluded}

      nil ->
        %{
          passed: count.(~r/Result: (\d+)(?:\/\d+)? passed/),
          failed: count.(~r/Failed: (\d+) tests?/),
          skipped: skipped,
          excluded: excluded
        }
    end
  end

  defp mix(args, opts) do
    env =
      [{"MIX_ENV", "test"}, {"NO_COLOR", "1"}, {"PATH", path()}, {"MIX_OS_CONCURRENCY_LOCK", "0"}] ++
        for({:build, dir} <- opts, do: {"MIX_BUILD_PATH", Path.join(dir, "test")}) ++
        for {:partition, n} <- opts, do: {"MIX_TEST_PARTITION", n}

    System.cmd(Path.join(elixir_bin(), "mix"), args,
      cd: @sample,
      env: env,
      stderr_to_stdout: true
    )
  end

  # The runs use the Elixir and Erlang installations of the current VM
  # directly. A version manager shim adds about 1 second to each run.
  defp elixir_bin, do: Path.expand("../../bin", :code.lib_dir(:elixir))

  defp path do
    Enum.join([elixir_bin(), Path.join(:code.root_dir(), "bin"), System.get_env("PATH")], ":")
  end

  describe "a passing suite" do
    setup %{passing: {output, status}} do
      %{output: output, status: status}
    end

    test "runs every *_test function and exits with 0", %{output: output, status: status} do
      assert status == 0, output
      assert summary(output) == %{passed: 15, failed: 0, skipped: 1, excluded: 10}
    end

    test "reports tests under their Erlang module and function name", %{output: output} do
      assert output =~ ":basics_tests [test/basics_tests.erl]"
      assert output =~ "* add_test"
      assert output =~ "* context_test"
    end

    test "honours the skip tag", %{output: output} do
      assert output =~ "skipped_test (skipped)"
    end
  end

  describe "a failing suite" do
    setup %{failing: {output, status}} do
      %{output: output, status: status}
    end

    test "exits with a failure status", %{output: output, status: status} do
      assert status == 2, output
      assert summary(output) == %{passed: 0, failed: 10, skipped: 0, excluded: 16}
    end

    test "?assertEqual is reported with the source line and a diff", %{output: output} do
      assert output =~ ~S"""
                  test/failing_tests.erl:8
                  ?assertEqual failed (failing_tests, line 9)
                  left is the expected term, right is the value
                  code:  ?assertEqual({ok, [x, y]}, {ok, [x, id(z)]}).
                  left:  {:ok, [:x, :y]}
                  right: {:ok, [:x, :z]}
                  stacktrace:
                    test/failing_tests.erl:9: (test)
             """
    end

    test "assert comments are part of the message", %{output: output} do
      assert output =~ "?assertEqual failed (failing_tests, line 18): one is not two"
    end

    test "other assert macros print their details in Erlang syntax", %{output: output} do
      assert output =~ ~S"""
                  ?assertMatch failed (failing_tests, line 12)
                  pattern: {ok, _}
                  value: {error,division_by_zero}
                  code: ?assertMatch({ok, _}, sample_math:divide(1, 0)).
             """

      assert output =~ ~S"""
                  ?assertException failed (failing_tests, line 21)
                  pattern: {error, badarg, [...]}
                  unexpected_success: 2
             """
    end

    test "assertions failing in a helper module point at both places", %{output: output} do
      assert output =~ ~S"""
                  ?assert failed (failing_helper, line 6)
                  expression: N > 10
                  expected: true
                  value: false
                  code: failing_helper:check(5).
                  stacktrace:
                    (sample 0.1.0) test/failing_helper.erl:6: :failing_helper.check/1
                    test/failing_tests.erl:24: (test)
             """
    end

    test "plain errors, exits and timeouts are left to ExUnit", %{output: output} do
      assert output =~ "** (MatchError) no match of right hand side value"
      assert output =~ "** (exit) :boom"
      assert output =~ "** (ExUnit.TimeoutError) test timed out after 50ms"
    end

    test "a bad setup return value fails the test with an explanation", %{output: output} do
      assert output =~
               "expected setup in bad_setup_tests to return ok, {ok, Context}, or Context"
    end
  end

  describe "selecting tests" do
    test "an Erlang file runs only that module", %{erl_file: {output, status}} do
      assert status == 0, output
      assert summary(output) == %{passed: 5, failed: 0, skipped: 0, excluded: 0}
    end

    test "FILE:LINE runs the test at that line", %{file_line: {output, status}} do
      assert status == 0, output
      assert output =~ "* tag_test"
      assert summary(output) == %{passed: 1, failed: 0, skipped: 0, excluded: 8}
    end

    test "Erlang and Elixir files can be mixed", %{mixed: {output, status}} do
      assert status == 0, output
      assert summary(output) == %{passed: 2, failed: 0, skipped: 0, excluded: 5}
    end

    test "an Elixir file does not run Erlang tests", %{elixir_file: {output, status}} do
      assert status == 0, output
      assert summary(output) == %{passed: 2, failed: 0, skipped: 0, excluded: 0}
    end

    test "an Erlang file that is not a test module runs nothing", %{helper_file: {output, status}} do
      assert status == 0, output
      assert summary(output) == %{passed: 0, failed: 0, skipped: 0, excluded: 0}
    end

    test "--only TAG selects tests by -tag", %{only_tag: {output, status}} do
      assert status == 0, output
      assert summary(output) == %{passed: 1, failed: 0, skipped: 0, excluded: 25}
    end

    test "--only module:NAME and test:NAME select by Erlang names", context do
      assert %{passed: 5, excluded: 21} = summary(elem(context.only_module, 0))
      assert %{passed: 1, excluded: 25} = summary(elem(context.only_test, 0))
    end

    test "--failed reruns the Erlang tests that failed", %{failed: [first, rerun]} do
      assert {output, 2} = first
      assert %{passed: 0, failed: 9} = summary(output)

      assert {output, 2} = rerun
      assert %{passed: 0, failed: 9} = summary(output)
    end

    test "--partitions splits Erlang files without running any twice", context do
      totals =
        for {output, 0} <- [context.partition_1, context.partition_2] do
          %{passed: passed, failed: 0, skipped: skipped} = summary(output)
          passed + skipped
        end

      assert length(totals) == 2
      assert Enum.sum(totals) == 15
    end
  end

  describe "compile time checks" do
    test "mistakes are reported by the compiler with file and line" do
      file = Path.expand("fixtures/bad_tests.erl", __DIR__)

      assert {:error, [{_file, errors}], _warnings} =
               :compile.file(String.to_charlist(file), [:return, :binary])

      messages =
        Map.new(errors, fn {location, module, reason} ->
          line = if is_tuple(location), do: elem(location, 0), else: location
          {line, IO.chardata_to_string(module.format_error(reason))}
        end)

      assert messages[3] =~ "-async expects true or false"
      assert messages[4] =~ "-moduletag cannot set 'line'"
      assert messages[6] =~ "-tag expects an atom"
      assert messages[8] =~ "test a_test is defined with both arity 0 and arity 1"
      assert messages[10] =~ "-tag must be followed by a test function"
      assert messages[14] =~ "callback setup is defined with both arity 0 and arity 1"
    end
  end

  describe "register/1" do
    test "rejects modules that are not ex_unit_erlang test modules" do
      assert_raise ArgumentError, ~r/is not an ex_unit_erlang test module/, fn ->
        ExUnitErlang.register([:lists])
      end
    end
  end
end
