defmodule PropCheck.Test.PrettyReportsDSL do
  @moduledoc """
  Tests for reporting the DSL models
  """
  use PropCheck
  use PropCheck.StateM.ModelDSL
  use ExUnit.Case

  require Logger

  import ExUnit.CaptureIO

  describe "print out on command crash" do
    # Command crashed.
    #
    # Commands:
    #    var1 = PrettyReportsDSL.noop(0)
    #         # -> :ok
    #         # Post state: [0]
    #
    #    var2 = PrettyReportsDSL.noop(1)
    #         # -> :ok
    #         # Post state: [1, 0]
    #
    #    var3 = PrettyReportsDSL.noop(2)
    #         # -> :ok
    #         # Post state: [2, 1, 0]
    #
    #    var4 = PrettyReportsDSL.noop(3)
    #         # -> :ok
    #         # Post state: [3, 2, 1, 0]
    #
    # #! var5 = PrettyReportsDSL.crash_command()
    #         # -> ** (RuntimeError) Crash
    #         #     test/statem_pretty_reports_test.exs:99: PropCheck.Test.PrettyReportsDSL.crash_command/0
    #         #     (proper) src/proper_statem.erl:581: :proper_statem.safe_apply/3
    #         #     (proper) src/proper_statem.erl:537: :proper_statem.run_commands/5
    #         #     (proper) src/proper_statem.erl:506: :proper_statem.run_commands/3
    #         #     test/statem_pretty_reports_test.exs:67: anonymous fn/0 in PropCheck.Test.PrettyReportsDSL."test command crash "/1
    #         #     (ex_unit) lib/ex_unit/capture_io.ex:151: ExUnit.CaptureIO.do_capture_io/2
    #         #     (ex_unit) lib/ex_unit/capture_io.ex:121: ExUnit.CaptureIO.do_capture_io/3
    #         #     test/statem_pretty_reports_test.exs:65: PropCheck.Test.PrettyReportsDSL."test command crash "/1
    #         #     (ex_unit) lib/ex_unit/runner.ex:355: ExUnit.Runner.exec_test/1
    #         #     (stdlib) timer.erl:166: :timer.tc/1
    #         #     (ex_unit) lib/ex_unit/runner.ex:306: anonymous fn/4 in ExUnit.Runner.spawn_test_monitor/4
    #         #
    #
    #
    # Last state:
    # [3, 2, 1, 0]

    setup do
      cmds = command_crash_seq()

      log =
        strip_ansi_sequences(
          capture_io(fn ->
            __MODULE__
            |> run_commands(cmds)
            |> print_report(cmds)
          end)
        )

      lines = String.split(log, "\n")

      [log: log, lines: lines]
    end

    test "has correct title", c do
      assert c.log =~ "Command crashed."
    end

    test "has listed commands only up to the crash ", c do
      commands_num =
        Enum.count(c.lines, &Regex.match?(~r/var\d+ = /, &1))

      assert commands_num == 5
    end

    test "last command is the failing one", c do
      last_cmd =
        c.lines
        |> Enum.filter(&Regex.match?(~r/var\d+ = /, &1))
        |> List.last()

      assert last_cmd =~ "#! var"
    end

    test "failing command returns exception", c do
      last_cmd_idx = Enum.find_index(c.lines, &(&1 =~ ~r/^#! var\d+ = /m))

      assert Enum.at(c.lines, last_cmd_idx + 1) =~ "# -> ** (RuntimeError) Crash"
    end

    test "commands' return values are printed out by default", c do
      cmd_idxs =
        c.lines
        |> Enum.with_index()
        |> Enum.filter(fn {line, _i} -> line =~ ~r/^var\d+ = /m end)

      for {_line, i} <- cmd_idxs,
          do: assert(Enum.at(c.lines, i + 1) =~ "# -> ")
    end

    test "post command states are printed out by default", c do
      cmd_idxs =
        c.lines
        |> Enum.with_index()
        |> Enum.filter(fn {line, _i} -> line =~ ~r/^var\d+ = /m end)
        |> Enum.with_index()
        |> Enum.map(fn {{line, line_idx}, cmd_idx} -> {line, line_idx, cmd_idx} end)

      for {_line, line_idx, cmd_idx} <- cmd_idxs do
        state = cmd_idx..0 |> inspect
        assert Enum.at(c.lines, line_idx + 2) =~ "# Post state: #{state}"
      end
    end

    test "correct last state is printed out", c do
      assert c.log =~ """
             Last state:
             [3, 2, 1, 0]
             """
    end
  end

  describe "print out on precondition crash (on execution phase)" do
    # Precondition crashed:
    # ** (RuntimeError) Crash
    #     test/statem_pretty_reports_test.exs:269: PropCheck.Test.PrettyReportsDSL.precondition/2
    #     (proper) src/proper_statem.erl:563: :proper_statem.check_precondition/3
    #     (proper) src/proper_statem.erl:535: :proper_statem.run_commands/5
    #     (proper) src/proper_statem.erl:506: :proper_statem.run_commands/3
    #     test/statem_pretty_reports_test.exs:180: anonymous fn/1 in PropCheck.Test.PrettyReportsDSL.__ex_unit_setup_1/1
    #     (ex_unit) lib/ex_unit/capture_io.ex:151: ExUnit.CaptureIO.do_capture_io/2
    #     (ex_unit) lib/ex_unit/capture_io.ex:121: ExUnit.CaptureIO.do_capture_io/3
    #     test/statem_pretty_reports_test.exs:178: PropCheck.Test.PrettyReportsDSL.__ex_unit_setup_1/1
    #     test/statem_pretty_reports_test.exs:1: PropCheck.Test.PrettyReportsDSL.__ex_unit__/2
    #     (ex_unit) lib/ex_unit/runner.ex:348: ExUnit.Runner.exec_test_setup/2
    #     (ex_unit) lib/ex_unit/runner.ex:307: anonymous fn/2 in ExUnit.Runner.spawn_test_monitor/4
    #     (stdlib) timer.erl:166: :timer.tc/1
    #     (ex_unit) lib/ex_unit/runner.ex:306: anonymous fn/4 in ExUnit.Runner.spawn_test_monitor/4
    #
    #
    # Commands:
    #    var1 = PrettyReportsDSL.noop(0)
    #         # -> :ok
    #         # Post state: [0]
    #
    #    var2 = PrettyReportsDSL.noop(1)
    #         # -> :ok
    #         # Post state: [1, 0]
    #
    #    var3 = PrettyReportsDSL.noop(2)
    #         # -> :ok
    #         # Post state: [2, 1, 0]
    #
    #    var4 = PrettyReportsDSL.noop(3)
    #         # -> :ok
    #
    # #! var5 = PrettyReportsDSL.crash_precond()
    #
    #
    # Last state:
    # [3, 2, 1, 0]

    setup do
      cmds = precond_crash_seq()

      log =
        strip_ansi_sequences(
          capture_io(fn ->
            __MODULE__
            |> run_commands(cmds)
            |> print_report(cmds)
          end)
        )

      lines = String.split(log, "\n")

      [log: log, lines: lines]
    end

    test "has correct title", c do
      assert c.log =~ "Precondition crashed:"
    end

    test "has listed commands only up to the crash ", c do
      commands_num = Enum.count(c.lines, &Regex.match?(~r/var\d+ = /, &1))

      assert commands_num == 5
    end

    test "last command is the failing one", c do
      last_cmd =
        c.lines
        |> Enum.filter(&Regex.match?(~r/var\d+ = /, &1))
        |> List.last()

      assert last_cmd =~ "#! var"
    end

    test "exception printed out after header", c do
      header_idx = 2
      assert Enum.at(c.lines, header_idx + 1) =~ ~r/^\*\* \(RuntimeError\) Crash$/
    end

    test "commands' return values are printed out by default", c do
      cmd_idxs =
        c.lines
        |> Enum.with_index()
        |> Enum.filter(fn {line, _i} -> line =~ ~r/^var\d+ = /m end)

      for {_line, i} <- cmd_idxs,
          do: assert(Enum.at(c.lines, i + 1) =~ "# -> ")
    end

    test "post command states are printed out by default", c do
      cmd_idxs =
        c.lines
        |> Enum.with_index()
        |> Enum.filter(fn {line, _i} -> line =~ ~r/^var\d+ = /m end)
        |> Enum.with_index()
        |> Enum.map(fn {{line, line_idx}, cmd_idx} -> {line, line_idx, cmd_idx} end)

      for {_line, line_idx, cmd_idx} <- cmd_idxs do
        state = cmd_idx..0 |> inspect
        assert Enum.at(c.lines, line_idx + 2) =~ "# Post state: #{state}"
      end
    end

    test "correct last state is printed out", c do
      assert c.log =~ """
             Last state:
             [3, 2, 1, 0]
             """
    end
  end

  describe "print out on precondition fail (on execution phase)" do
    # Precondition failed.
    #
    # Commands:
    #    var1 = PrettyReportsDSL.noop(0)
    #         # -> :ok
    #         # Post state: [0]
    #
    #    var2 = PrettyReportsDSL.noop(1)
    #         # -> :ok
    #         # Post state: [1, 0]
    #
    #    var3 = PrettyReportsDSL.noop(2)
    #         # -> :ok
    #         # Post state: [2, 1, 0]
    #
    #    var4 = PrettyReportsDSL.noop(3)
    #         # -> :ok
    #
    # #! var5 = PrettyReportsDSL.fail_precond()
    #
    #
    # Last state:
    # [3, 2, 1, 0]

    setup do
      cmds = precond_fail_seq()

      log =
        strip_ansi_sequences(
          capture_io(fn ->
            __MODULE__
            |> run_commands(cmds)
            |> print_report(cmds)
          end)
        )

      lines = String.split(log, "\n")

      [log: log, lines: lines]
    end

    test "has correct title", c do
      assert c.log =~ "Precondition failed."
    end

    test "has listed commands only up to the crash ", c do
      commands_num =
        Enum.count(c.lines, &Regex.match?(~r/var\d+ = /, &1))

      assert commands_num == 5
    end

    test "last command is the failing one", c do
      last_cmd =
        c.lines
        |> Enum.filter(&Regex.match?(~r/var\d+ = /, &1))
        |> List.last()

      assert last_cmd =~ "#! var"
    end

    test "no return value printed on failing command", c do
      last_cmd_idx = Enum.find_index(c.lines, &(&1 =~ ~r/^#! var\d+ = /m))

      assert Enum.at(c.lines, last_cmd_idx + 1) == ""
    end

    test "commands' return values are printed out by default", c do
      cmd_idxs =
        c.lines
        |> Enum.with_index()
        |> Enum.filter(fn {line, _i} -> line =~ ~r/^var\d+ = /m end)

      for {_line, i} <- cmd_idxs,
          do: assert(Enum.at(c.lines, i + 1) =~ "# -> ")
    end

    test "post command states are printed out by default", c do
      cmd_idxs =
        c.lines
        |> Enum.with_index()
        |> Enum.filter(fn {line, _i} -> line =~ ~r/^var\d+ = /m end)
        |> Enum.with_index()
        |> Enum.map(fn {{line, line_idx}, cmd_idx} -> {line, line_idx, cmd_idx} end)

      for {_line, line_idx, cmd_idx} <- cmd_idxs do
        state = cmd_idx..0 |> inspect
        assert Enum.at(c.lines, line_idx + 2) =~ "# Post state: #{state}"
      end
    end

    test "correct last state is printed out", c do
      assert c.log =~ """
             Last state:
             [3, 2, 1, 0]
             """
    end
  end

  describe "print out on postcondition crash (on execution phase)" do
    # Postcondition crashed:
    # ** (RuntimeError) Crash
    #     test/statem_pretty_reports_test.exs:392: PropCheck.Test.PrettyReportsDSL.postcondition/3
    #     (proper) src/proper_statem.erl:572: :proper_statem.check_postcondition/4
    #     (proper) src/proper_statem.erl:541: :proper_statem.run_commands/5
    #     (proper) src/proper_statem.erl:506: :proper_statem.run_commands/3
    #     test/statem_pretty_reports_test.exs:295: anonymous fn/1 in PropCheck.Test.PrettyReportsDSL.__ex_unit_setup_2/1
    #     (ex_unit) lib/ex_unit/capture_io.ex:151: ExUnit.CaptureIO.do_capture_io/2
    #     (ex_unit) lib/ex_unit/capture_io.ex:121: ExUnit.CaptureIO.do_capture_io/3
    #     test/statem_pretty_reports_test.exs:293: PropCheck.Test.PrettyReportsDSL.__ex_unit_setup_2/1
    #     test/statem_pretty_reports_test.exs:1: PropCheck.Test.PrettyReportsDSL.__ex_unit__/2
    #     (ex_unit) lib/ex_unit/runner.ex:348: ExUnit.Runner.exec_test_setup/2
    #     (ex_unit) lib/ex_unit/runner.ex:307: anonymous fn/2 in ExUnit.Runner.spawn_test_monitor/4
    #     (stdlib) timer.erl:166: :timer.tc/1
    #     (ex_unit) lib/ex_unit/runner.ex:306: anonymous fn/4 in ExUnit.Runner.spawn_test_monitor/4
    #
    #
    # Commands:
    #    var1 = PrettyReportsDSL.noop(0)
    #         # -> :ok
    #         # Post state: [0]
    #
    #    var2 = PrettyReportsDSL.noop(1)
    #         # -> :ok
    #         # Post state: [1, 0]
    #
    #    var3 = PrettyReportsDSL.noop(2)
    #         # -> :ok
    #         # Post state: [2, 1, 0]
    #
    #    var4 = PrettyReportsDSL.noop(3)
    #         # -> :ok
    #         # Post state: [3, 2, 1, 0]
    #
    # #! var5 = PrettyReportsDSL.crash_postcond()
    #         # -> :ok
    #
    #
    # Last state:
    # [3, 2, 1, 0]

    setup do
      cmds = postcond_crash_seq()

      log =
        strip_ansi_sequences(
          capture_io(fn ->
            __MODULE__
            |> run_commands(cmds)
            |> print_report(cmds)
          end)
        )

      lines = String.split(log, "\n")

      [log: log, lines: lines]
    end

    test "has correct title", c do
      assert c.log =~ "Postcondition crashed:"
    end

    test "has listed commands only up to the crash ", c do
      commands_num =
        Enum.count(c.lines, &Regex.match?(~r/var\d+ = /, &1))

      assert commands_num == 5
    end

    test "last command is the failing one", c do
      last_cmd =
        c.lines
        |> Enum.filter(&Regex.match?(~r/var\d+ = /, &1))
        |> List.last()

      assert last_cmd =~ "#! var"
    end

    test "exception printed out after header", c do
      header_idx = 2
      assert Enum.at(c.lines, header_idx + 1) =~ ~r/^\*\* \(RuntimeError\) Crash$/
    end

    test "commands' return values are printed out by default", c do
      cmd_idxs =
        c.lines
        |> Enum.with_index()
        |> Enum.filter(fn {line, _i} -> line =~ ~r/^var\d+ = /m end)

      for {_line, i} <- cmd_idxs,
          do: assert(Enum.at(c.lines, i + 1) =~ "# -> ")
    end

    test "post command states are printed out by default", c do
      cmd_idxs =
        c.lines
        |> Enum.with_index()
        |> Enum.filter(fn {line, _i} -> line =~ ~r/^var\d+ = /m end)
        |> Enum.with_index()
        |> Enum.map(fn {{line, line_idx}, cmd_idx} -> {line, line_idx, cmd_idx} end)

      for {_line, line_idx, cmd_idx} <- cmd_idxs do
        state = cmd_idx..0 |> inspect
        assert Enum.at(c.lines, line_idx + 2) =~ "# Post state: #{state}"
      end
    end

    test "correct last state is printed out", c do
      assert c.log =~ """
             Last state:
             [3, 2, 1, 0]
             """
    end
  end

  describe "print out on postcondition fail (on execution phase)" do
    # Postcondition failed.
    #
    # Commands:
    #    var1 = PrettyReportsDSL.noop(0)
    #         # -> :ok
    #         # Post state: [0]
    #
    #    var2 = PrettyReportsDSL.noop(1)
    #         # -> :ok
    #         # Post state: [1, 0]
    #
    #    var3 = PrettyReportsDSL.noop(2)
    #         # -> :ok
    #         # Post state: [2, 1, 0]
    #
    #    var4 = PrettyReportsDSL.noop(3)
    #         # -> :ok
    #         # Post state: [3, 2, 1, 0]
    #
    # #! var5 = PrettyReportsDSL.fail_postcond()
    #         # -> :ok
    #
    #
    # Last state:
    # [3, 2, 1, 0]

    setup do
      cmds = postcond_fail_seq()

      log =
        strip_ansi_sequences(
          capture_io(fn ->
            __MODULE__
            |> run_commands(cmds)
            |> print_report(cmds)
          end)
        )

      lines = String.split(log, "\n")

      [log: log, lines: lines]
    end

    test "has correct title", c do
      assert c.log =~ "Postcondition failed."
    end

    test "has listed commands only up to the crash ", c do
      commands_num =
        Enum.count(c.lines, &Regex.match?(~r/var\d+ = /, &1))

      assert commands_num == 5
    end

    test "last command is the failing one", c do
      last_cmd =
        c.lines
        |> Enum.filter(&Regex.match?(~r/var\d+ = /, &1))
        |> List.last()

      assert last_cmd =~ "#! var"
    end

    test "return value printed on failing command", c do
      last_cmd_idx = Enum.find_index(c.lines, &(&1 =~ ~r/^#! var\d+ = /m))

      assert Enum.at(c.lines, last_cmd_idx + 1) =~ "# -> :ok"
    end

    test "commands' return values are printed out by default", c do
      cmd_idxs =
        c.lines
        |> Enum.with_index()
        |> Enum.filter(fn {line, _i} -> line =~ ~r/^var\d+ = /m end)

      for {_line, i} <- cmd_idxs,
          do: assert(Enum.at(c.lines, i + 1) =~ "# -> ")
    end

    test "post command states are printed out by default", c do
      cmd_idxs =
        c.lines
        |> Enum.with_index()
        |> Enum.filter(fn {line, _i} -> line =~ ~r/^var\d+ = /m end)
        |> Enum.with_index()
        |> Enum.map(fn {{line, line_idx}, cmd_idx} -> {line, line_idx, cmd_idx} end)

      for {_line, line_idx, cmd_idx} <- cmd_idxs do
        state = cmd_idx..0 |> inspect
        assert Enum.at(c.lines, line_idx + 2) =~ "# Post state: #{state}"
      end
    end

    test "correct last state is printed out", c do
      assert c.log =~ """
             Last state:
             [3, 2, 1, 0]
             """
    end
  end

  describe "initial state passed to `run_commands`," do
    defp run_cmds(args = [cmd_seq | _]) do
      strip_ansi_sequences(
        capture_io(fn ->
          PropCheck.StateM
          |> apply(:run_commands, [__MODULE__ | args])
          |> print_report(cmd_seq)
        end)
      )
    end

    test "doesn't change a ok printout" do
      assert run_cmds([ok_seq()]) == run_cmds([ok_seq(), initial_state()])
    end

    test "doesn't change a command crash printout" do
      assert run_cmds([command_crash_seq()]) == run_cmds([command_crash_seq(), initial_state()])
    end

    test "doesn't change a precond fail printout" do
      assert run_cmds([precond_fail_seq()]) == run_cmds([precond_fail_seq(), initial_state()])
    end

    test "doesn't change a precond crash printout" do
      assert run_cmds([precond_crash_seq()]) == run_cmds([precond_crash_seq(), initial_state()])
    end

    test "doesn't change a postcond fail printout" do
      assert run_cmds([postcond_fail_seq()]) == run_cmds([postcond_fail_seq(), initial_state()])
    end

    test "doesn't change a postcond crash printout" do
      assert run_cmds([postcond_crash_seq()]) == run_cmds([postcond_crash_seq(), initial_state()])
    end
  end

  describe "printout options," do
    defp run(opts) do
      cmds = postcond_fail_seq()

      log =
        strip_ansi_sequences(
          capture_io(fn ->
            __MODULE__
            |> run_commands(cmds)
            |> print_report(cmds, opts)
          end)
        )

      lines = String.split(log, "\n")

      %{log: log, lines: lines}
    end

    test "last state can be suppressed" do
      c = run(last_state: false)
      refute c.log =~ "Last state:"
    end

    test "post state is enabled by default" do
      c = run([])
      assert c.log =~ "# Post state:"
    end

    test "post state can be suppressed" do
      c = run(post_cmd_state: false)
      refute c.log =~ "# Post state:"
    end

    test "pre state is disabled by default" do
      c = run([])
      refute c.log =~ "# pre state:"
    end

    test "pre state can be enabled" do
      c = run(pre_cmd_state: true)
      assert c.log =~ "# Pre state:"
    end

    test "command arguments as literals is enabled by default" do
      c = run([])
      assert c.log =~ "var1 = PrettyReportsDSL.noop(0)"
      assert c.log =~ "var2 = PrettyReportsDSL.noop(1)"
      assert c.log =~ "var3 = PrettyReportsDSL.noop(2)"
    end

    test "command arguments as literals can be suppressed" do
      c = run(cmd_args: false)
      assert c.log =~ "var1 = PrettyReportsDSL.noop(arg1_1)"
      assert c.log =~ "var2 = PrettyReportsDSL.noop(arg2_1)"
      assert c.log =~ "var3 = PrettyReportsDSL.noop(arg3_1)"
    end

    test "module aliasing can be disabled" do
      c = run(alias: [])
      assert c.log =~ "var1 = PropCheck.Test.PrettyReportsDSL.noop(0)"
      assert c.log =~ "var2 = PropCheck.Test.PrettyReportsDSL.noop(1)"
      assert c.log =~ "var3 = PropCheck.Test.PrettyReportsDSL.noop(2)"
    end

    test "module aliasing accepts a list and a single element" do
      c = run(alias: PropCheck.Test.PrettyReportsDSL)
      assert c.log =~ "var1 = PrettyReportsDSL.noop(0)"
      assert c.log =~ "var2 = PrettyReportsDSL.noop(1)"
      assert c.log =~ "var3 = PrettyReportsDSL.noop(2)"

      c = run(alias: [PropCheck.Test.PrettyReportsDSL])
      assert c.log =~ "var1 = PrettyReportsDSL.noop(0)"
      assert c.log =~ "var2 = PrettyReportsDSL.noop(1)"
      assert c.log =~ "var3 = PrettyReportsDSL.noop(2)"
    end

    test "module aliasing works in 'alias as' mode" do
      c = run(alias: [{PropCheck.Test.PrettyReportsDSL, X}])
      assert c.log =~ "var1 = X.noop(0)"
      assert c.log =~ "var2 = X.noop(1)"
      assert c.log =~ "var3 = X.noop(2)"
    end
  end

  #
  #
  # StateM.ModelDSL implementation
  #

  def initial_state, do: []

  def command_gen(_state) do
    oneof([
      {:noop, [any()]},
      {:crash_precond, []},
      {:fail_precond, []},
      {:crash_postcond, []},
      {:fail_postcond, []},
      {:crash_command, []}
    ])
  end

  defcommand :noop do
    def impl(x), do: x
    def next(old_state, _args, _call_res), do: [length(old_state) | old_state]
  end

  defcommand :crash_precond do
    def impl, do: :ok

    def pre(state, _args) do
      if not Keyword.keyword?(state) do
        raise "Crash"
      end
    end
  end

  defcommand :fail_precond do
    def impl, do: :ok

    def pre(state, _args) do
      if not Keyword.keyword?(state) do
        false
      end
    end
  end

  defcommand :crash_postcond do
    def impl, do: :ok
    def post(_state, _args, _call_res), do: raise("Crash")
  end

  defcommand :fail_postcond do
    def impl, do: :ok
    def post(_state, _args, _call_res), do: false
  end

  defcommand :crash_command do
    def impl, do: raise("Crash")
  end

  #
  #
  # Helpers
  #

  defp ok_seq,
    do: [
      {:set, {:var, 1}, {:call, __MODULE__, :noop, [0]}},
      {:set, {:var, 1}, {:call, __MODULE__, :noop, [1]}},
      {:set, {:var, 1}, {:call, __MODULE__, :noop, [2]}},
      {:set, {:var, 1}, {:call, __MODULE__, :noop, [3]}},
      {:set, {:var, 1}, {:call, __MODULE__, :noop, [4]}},
      {:set, {:var, 1}, {:call, __MODULE__, :noop, [5]}}
    ]

  defp command_crash_seq,
    do: [
      {:set, {:var, 1}, {:call, __MODULE__, :noop, [0]}},
      {:set, {:var, 2}, {:call, __MODULE__, :noop, [1]}},
      {:set, {:var, 3}, {:call, __MODULE__, :noop, [2]}},
      {:set, {:var, 4}, {:call, __MODULE__, :noop, [3]}},
      {:set, {:var, 5}, {:call, __MODULE__, :crash_command, []}},
      {:set, {:var, 6}, {:call, __MODULE__, :noop, [4]}},
      {:set, {:var, 7}, {:call, __MODULE__, :noop, [5]}}
    ]

  defp precond_crash_seq,
    do: [
      {:set, {:var, 1}, {:call, __MODULE__, :noop, [0]}},
      {:set, {:var, 2}, {:call, __MODULE__, :noop, [1]}},
      {:set, {:var, 3}, {:call, __MODULE__, :noop, [2]}},
      {:set, {:var, 4}, {:call, __MODULE__, :noop, [3]}},
      {:set, {:var, 5}, {:call, __MODULE__, :crash_precond, []}},
      {:set, {:var, 6}, {:call, __MODULE__, :noop, [4]}},
      {:set, {:var, 7}, {:call, __MODULE__, :noop, [5]}}
    ]

  defp precond_fail_seq,
    do: [
      {:set, {:var, 1}, {:call, __MODULE__, :noop, [0]}},
      {:set, {:var, 2}, {:call, __MODULE__, :noop, [1]}},
      {:set, {:var, 3}, {:call, __MODULE__, :noop, [2]}},
      {:set, {:var, 4}, {:call, __MODULE__, :noop, [3]}},
      {:set, {:var, 5}, {:call, __MODULE__, :fail_precond, []}},
      {:set, {:var, 6}, {:call, __MODULE__, :noop, [4]}},
      {:set, {:var, 7}, {:call, __MODULE__, :noop, [5]}}
    ]

  defp postcond_crash_seq,
    do: [
      {:set, {:var, 1}, {:call, __MODULE__, :noop, [0]}},
      {:set, {:var, 2}, {:call, __MODULE__, :noop, [1]}},
      {:set, {:var, 3}, {:call, __MODULE__, :noop, [2]}},
      {:set, {:var, 4}, {:call, __MODULE__, :noop, [3]}},
      {:set, {:var, 5}, {:call, __MODULE__, :crash_postcond, []}},
      {:set, {:var, 6}, {:call, __MODULE__, :noop, [4]}},
      {:set, {:var, 7}, {:call, __MODULE__, :noop, [5]}}
    ]

  defp postcond_fail_seq,
    do: [
      {:set, {:var, 1}, {:call, __MODULE__, :noop, [0]}},
      {:set, {:var, 2}, {:call, __MODULE__, :noop, [1]}},
      {:set, {:var, 3}, {:call, __MODULE__, :noop, [2]}},
      {:set, {:var, 4}, {:call, __MODULE__, :noop, [3]}},
      {:set, {:var, 5}, {:call, __MODULE__, :fail_postcond, []}},
      {:set, {:var, 6}, {:call, __MODULE__, :noop, [4]}},
      {:set, {:var, 7}, {:call, __MODULE__, :noop, [5]}}
    ]

  defp strip_ansi_sequences(str) do
    r = ~r/\e\[.*?m/
    Regex.replace(r, str, "")
  end
end
