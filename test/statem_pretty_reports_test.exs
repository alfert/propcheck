defmodule PropCheck.Test.PrettyReports do
  use PropCheck
  use PropCheck.StateM
  use ExUnit.Case

  require Logger

  import ExUnit.CaptureIO

  describe "print out on command crash" do
    # Command crashed.
    #
    # Commands:
    #    var1 = PropCheck.Test.PrettyReports.noop(0)
    #         # -> :ok
    #         # Post state: [0]
    #
    #    var2 = PropCheck.Test.PrettyReports.noop(1)
    #         # -> :ok
    #         # Post state: [1, 0]
    #
    #    var3 = PropCheck.Test.PrettyReports.noop(2)
    #         # -> :ok
    #         # Post state: [2, 1, 0]
    #
    #    var4 = PropCheck.Test.PrettyReports.noop(3)
    #         # -> :ok
    #         # Post state: [3, 2, 1, 0]
    #
    # #! var5 = PropCheck.Test.PrettyReports.crash_command()
    #         # -> ** (RuntimeError) Crash
    #         #     test/statem_pretty_reports_test.exs:99: PropCheck.Test.PrettyReports.crash_command/0
    #         #     (proper) src/proper_statem.erl:581: :proper_statem.safe_apply/3
    #         #     (proper) src/proper_statem.erl:537: :proper_statem.run_commands/5
    #         #     (proper) src/proper_statem.erl:506: :proper_statem.run_commands/3
    #         #     test/statem_pretty_reports_test.exs:67: anonymous fn/0 in PropCheck.Test.PrettyReports."test command crash "/1
    #         #     (ex_unit) lib/ex_unit/capture_io.ex:151: ExUnit.CaptureIO.do_capture_io/2
    #         #     (ex_unit) lib/ex_unit/capture_io.ex:121: ExUnit.CaptureIO.do_capture_io/3
    #         #     test/statem_pretty_reports_test.exs:65: PropCheck.Test.PrettyReports."test command crash "/1
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

      log = strip_ansi_sequences capture_io(fn ->
        __MODULE__
        |> run_commands(cmds)
        |> print_report(cmds)
      end)

      lines = String.split(log, "\n")

      [log: log, lines: lines]
    end

    test "has correct title", c do
      assert c.log =~ "Command crashed."
    end

    test "has listed commands only up to the crash ", c do
      commands_num =
        c.lines
        |> Enum.filter(& Regex.match?(~r/var\d+ = /, &1))
        |> Enum.count()

      assert commands_num == 5
    end

    test "last command is the failing one", c do
      last_cmd =
        c.lines
        |> Enum.filter(& Regex.match?(~r/var\d+ = /, &1))
        |> List.last()

      assert last_cmd =~ "#! var"
    end

    test "failing command returns exception", c do
      last_cmd_idx = Enum.find_index(c.lines, & &1 =~ ~r/^#! var\d+ = /m)

      assert Enum.at(c.lines, last_cmd_idx + 1) =~ "# -> ** (RuntimeError) Crash"
    end

    test "commands' return values are printed out by default", c do
      cmd_idxs =
        c.lines
        |> Enum.with_index()
        |> Enum.filter(fn {line, _i} -> line =~ ~r/^var\d+ = /m end)

      for {_line, i} <- cmd_idxs,
        do: assert Enum.at(c.lines, i + 1) =~ "# -> "
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
    #     test/statem_pretty_reports_test.exs:269: PropCheck.Test.PrettyReports.precondition/2
    #     (proper) src/proper_statem.erl:563: :proper_statem.check_precondition/3
    #     (proper) src/proper_statem.erl:535: :proper_statem.run_commands/5
    #     (proper) src/proper_statem.erl:506: :proper_statem.run_commands/3
    #     test/statem_pretty_reports_test.exs:180: anonymous fn/1 in PropCheck.Test.PrettyReports.__ex_unit_setup_1/1
    #     (ex_unit) lib/ex_unit/capture_io.ex:151: ExUnit.CaptureIO.do_capture_io/2
    #     (ex_unit) lib/ex_unit/capture_io.ex:121: ExUnit.CaptureIO.do_capture_io/3
    #     test/statem_pretty_reports_test.exs:178: PropCheck.Test.PrettyReports.__ex_unit_setup_1/1
    #     test/statem_pretty_reports_test.exs:1: PropCheck.Test.PrettyReports.__ex_unit__/2
    #     (ex_unit) lib/ex_unit/runner.ex:348: ExUnit.Runner.exec_test_setup/2
    #     (ex_unit) lib/ex_unit/runner.ex:307: anonymous fn/2 in ExUnit.Runner.spawn_test_monitor/4
    #     (stdlib) timer.erl:166: :timer.tc/1
    #     (ex_unit) lib/ex_unit/runner.ex:306: anonymous fn/4 in ExUnit.Runner.spawn_test_monitor/4
    #
    #
    # Commands:
    #    var1 = PropCheck.Test.PrettyReports.noop(0)
    #         # -> :ok
    #         # Post state: [0]
    #
    #    var2 = PropCheck.Test.PrettyReports.noop(1)
    #         # -> :ok
    #         # Post state: [1, 0]
    #
    #    var3 = PropCheck.Test.PrettyReports.noop(2)
    #         # -> :ok
    #         # Post state: [2, 1, 0]
    #
    #    var4 = PropCheck.Test.PrettyReports.noop(3)
    #         # -> :ok
    #
    # #! var5 = PropCheck.Test.PrettyReports.crash_precond()
    #
    #
    # Last state:
    # [3, 2, 1, 0]

    setup do
      cmds = precond_crash_seq()

      log = strip_ansi_sequences capture_io(fn ->
        __MODULE__
        |> run_commands(cmds)
        |> print_report(cmds)
      end)

      lines = String.split(log, "\n")

      [log: log, lines: lines]
    end

    test "has correct title", c do
      assert c.log =~ "Precondition crashed:"
    end

    test "has listed commands only up to the crash ", c do
      commands_num =
        c.lines
        |> Enum.filter(& Regex.match?(~r/var\d+ = /, &1))
        |> Enum.count()

      assert commands_num == 5
    end

    test "last command is the failing one", c do
      last_cmd =
        c.lines
        |> Enum.filter(& Regex.match?(~r/var\d+ = /, &1))
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
        do: assert Enum.at(c.lines, i + 1) =~ "# -> "
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
    #    var1 = PropCheck.Test.PrettyReports.noop(0)
    #         # -> :ok
    #         # Post state: [0]
    #
    #    var2 = PropCheck.Test.PrettyReports.noop(1)
    #         # -> :ok
    #         # Post state: [1, 0]
    #
    #    var3 = PropCheck.Test.PrettyReports.noop(2)
    #         # -> :ok
    #         # Post state: [2, 1, 0]
    #
    #    var4 = PropCheck.Test.PrettyReports.noop(3)
    #         # -> :ok
    #
    # #! var5 = PropCheck.Test.PrettyReports.fail_precond()
    #
    #
    # Last state:
    # [3, 2, 1, 0]

    setup do
      cmds = precond_fail_seq()

      log = strip_ansi_sequences capture_io(fn ->
        __MODULE__
        |> run_commands(cmds)
        |> print_report(cmds)
      end)

      lines = String.split(log, "\n")

      [log: log, lines: lines]
    end

    test "has correct title", c do
      assert c.log =~ "Precondition failed."
    end

    test "has listed commands only up to the crash ", c do
      commands_num =
        c.lines
        |> Enum.filter(& Regex.match?(~r/var\d+ = /, &1))
        |> Enum.count()

      assert commands_num == 5
    end

    test "last command is the failing one", c do
      last_cmd =
        c.lines
        |> Enum.filter(& Regex.match?(~r/var\d+ = /, &1))
        |> List.last()

      assert last_cmd =~ "#! var"
    end

    test "no return value printed on failing command", c do
      last_cmd_idx = Enum.find_index(c.lines, & &1 =~ ~r/^#! var\d+ = /m)

      assert Enum.at(c.lines, last_cmd_idx + 1) == ""
    end

    test "commands' return values are printed out by default", c do
      cmd_idxs =
        c.lines
        |> Enum.with_index()
        |> Enum.filter(fn {line, _i} -> line =~ ~r/^var\d+ = /m end)

      for {_line, i} <- cmd_idxs,
        do: assert Enum.at(c.lines, i + 1) =~ "# -> "
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
    #     test/statem_pretty_reports_test.exs:392: PropCheck.Test.PrettyReports.postcondition/3
    #     (proper) src/proper_statem.erl:572: :proper_statem.check_postcondition/4
    #     (proper) src/proper_statem.erl:541: :proper_statem.run_commands/5
    #     (proper) src/proper_statem.erl:506: :proper_statem.run_commands/3
    #     test/statem_pretty_reports_test.exs:295: anonymous fn/1 in PropCheck.Test.PrettyReports.__ex_unit_setup_2/1
    #     (ex_unit) lib/ex_unit/capture_io.ex:151: ExUnit.CaptureIO.do_capture_io/2
    #     (ex_unit) lib/ex_unit/capture_io.ex:121: ExUnit.CaptureIO.do_capture_io/3
    #     test/statem_pretty_reports_test.exs:293: PropCheck.Test.PrettyReports.__ex_unit_setup_2/1
    #     test/statem_pretty_reports_test.exs:1: PropCheck.Test.PrettyReports.__ex_unit__/2
    #     (ex_unit) lib/ex_unit/runner.ex:348: ExUnit.Runner.exec_test_setup/2
    #     (ex_unit) lib/ex_unit/runner.ex:307: anonymous fn/2 in ExUnit.Runner.spawn_test_monitor/4
    #     (stdlib) timer.erl:166: :timer.tc/1
    #     (ex_unit) lib/ex_unit/runner.ex:306: anonymous fn/4 in ExUnit.Runner.spawn_test_monitor/4
    #
    #
    # Commands:
    #    var1 = PropCheck.Test.PrettyReports.noop(0)
    #         # -> :ok
    #         # Post state: [0]
    #
    #    var2 = PropCheck.Test.PrettyReports.noop(1)
    #         # -> :ok
    #         # Post state: [1, 0]
    #
    #    var3 = PropCheck.Test.PrettyReports.noop(2)
    #         # -> :ok
    #         # Post state: [2, 1, 0]
    #
    #    var4 = PropCheck.Test.PrettyReports.noop(3)
    #         # -> :ok
    #         # Post state: [3, 2, 1, 0]
    #
    # #! var5 = PropCheck.Test.PrettyReports.crash_postcond()
    #         # -> :ok
    #
    #
    # Last state:
    # [3, 2, 1, 0]

    setup do
      cmds = postcond_crash_seq()

      log = strip_ansi_sequences capture_io(fn ->
        __MODULE__
        |> run_commands(cmds)
        |> print_report(cmds)
      end)

      lines = String.split(log, "\n")

      [log: log, lines: lines]
    end

    test "has correct title", c do
      assert c.log =~ "Postcondition crashed:"
    end

    test "has listed commands only up to the crash ", c do
      commands_num =
        c.lines
        |> Enum.filter(& Regex.match?(~r/var\d+ = /, &1))
        |> Enum.count()

      assert commands_num == 5
    end

    test "last command is the failing one", c do
      last_cmd =
        c.lines
        |> Enum.filter(& Regex.match?(~r/var\d+ = /, &1))
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
        do: assert Enum.at(c.lines, i + 1) =~ "# -> "
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
    #    var1 = PropCheck.Test.PrettyReports.noop(0)
    #         # -> :ok
    #         # Post state: [0]
    #
    #    var2 = PropCheck.Test.PrettyReports.noop(1)
    #         # -> :ok
    #         # Post state: [1, 0]
    #
    #    var3 = PropCheck.Test.PrettyReports.noop(2)
    #         # -> :ok
    #         # Post state: [2, 1, 0]
    #
    #    var4 = PropCheck.Test.PrettyReports.noop(3)
    #         # -> :ok
    #         # Post state: [3, 2, 1, 0]
    #
    # #! var5 = PropCheck.Test.PrettyReports.fail_postcond()
    #         # -> :ok
    #
    #
    # Last state:
    # [3, 2, 1, 0]

    setup do
      cmds = postcond_fail_seq()

      log = strip_ansi_sequences capture_io(fn ->
        __MODULE__
        |> run_commands(cmds)
        |> print_report(cmds)
      end)

      lines = String.split(log, "\n")

      [log: log, lines: lines]
    end

    test "has correct title", c do
      assert c.log =~ "Postcondition failed."
    end

    test "has listed commands only up to the crash ", c do
      commands_num =
        c.lines
        |> Enum.filter(& Regex.match?(~r/var\d+ = /, &1))
        |> Enum.count()

      assert commands_num == 5
    end

    test "last command is the failing one", c do
      last_cmd =
        c.lines
        |> Enum.filter(& Regex.match?(~r/var\d+ = /, &1))
        |> List.last()

      assert last_cmd =~ "#! var"
    end

    test "return value printed on failing command", c do
      last_cmd_idx = Enum.find_index(c.lines, & &1 =~ ~r/^#! var\d+ = /m)

      assert Enum.at(c.lines, last_cmd_idx + 1) =~ "# -> :ok"
    end

    test "commands' return values are printed out by default", c do
      cmd_idxs =
        c.lines
        |> Enum.with_index()
        |> Enum.filter(fn {line, _i} -> line =~ ~r/^var\d+ = /m end)

      for {_line, i} <- cmd_idxs,
        do: assert Enum.at(c.lines, i + 1) =~ "# -> "
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
      strip_ansi_sequences capture_io(fn ->
        PropCheck.StateM
        |> apply(:run_commands, [__MODULE__ | args])
        |> print_report(cmd_seq)
      end)
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

      log = strip_ansi_sequences capture_io(fn ->
        __MODULE__
        |> run_commands(cmds)
        |> print_report(cmds, opts)
      end)

      lines = String.split(log, "\n")

      %{log: log, lines: lines}
    end

    test "last state can be suppressed" do
      c = run [last_state: false]
      refute c.log =~ "Last state:"
    end

    test "post state is enabled by default" do
      c = run []
      assert c.log =~ "# Post state:"
    end

    test "post state can be suppressed" do
      c = run [post_cmd_state: false]
      refute c.log =~ "# Post state:"
    end

    test "pre state is disabled by default" do
      c = run []
      refute c.log =~ "# pre state:"
    end

    test "pre state can be enabled" do
      c = run [pre_cmd_state: true]
      assert c.log =~ "# Pre state:"
    end

    test "command arguments as literals is enabled by default" do
      c = run []
      assert c.log =~ "var1 = PropCheck.Test.PrettyReports.noop(0)"
      assert c.log =~ "var2 = PropCheck.Test.PrettyReports.noop(1)"
      assert c.log =~ "var3 = PropCheck.Test.PrettyReports.noop(2)"
    end

    test "command arguments as literals can be suppressed" do
      c = run [cmd_args: false]
      assert c.log =~ "var1 = PropCheck.Test.PrettyReports.noop(arg1_1)"
      assert c.log =~ "var2 = PropCheck.Test.PrettyReports.noop(arg2_1)"
      assert c.log =~ "var3 = PropCheck.Test.PrettyReports.noop(arg3_1)"
    end
  end

  #
  #
  # StateM implementation
  #

  def initial_state, do: []

  def command(_state) do
    oneof [
      {:call, __MODULE__, :noop, [any()]},
      {:call, __MODULE__, :crash_precond, []},
      {:call, __MODULE__, :fail_precond, []},
      {:call, __MODULE__, :crash_postcond, []},
      {:call, __MODULE__, :fail_postcond, []},
      {:call, __MODULE__, :crash_command, []},
    ]
  end

  def precondition(state, {:call, _, :crash_precond, _}) do
    if not Keyword.keyword?(state) do
      raise "Crash"
    end
  end
  def precondition(state, {:call, _, :fail_precond, _}) do
    if not Keyword.keyword?(state) do
      false
    end
  end
  def precondition(_state, _), do: true

  def postcondition(_state, {:call, _, :crash_postcond, _}, _result) do
    raise "Crash"
  end
  def postcondition(_state, {:call, _, :fail_postcond, _}, _result) do
    false
  end
  def postcondition(_state, _, _result) do
    true
  end

  def next_state(state, _, {:call, _, :noop, _}) do
    [length(state) | state]
  end
  def next_state(state, _, _) do
    state
  end

  def noop(_) do
    :ok
  end

  def crash_command do
    raise "Crash"
  end

  def fail_precond, do: :ok
  def crash_precond, do: :ok

  def fail_postcond, do: :ok
  def crash_postcond, do: :ok

  #
  #
  # Helpers
  #

  defp ok_seq, do: [
    {:set, {:var, 1}, {:call, __MODULE__, :noop, [0]}},
    {:set, {:var, 1}, {:call, __MODULE__, :noop, [1]}},
    {:set, {:var, 1}, {:call, __MODULE__, :noop, [2]}},
    {:set, {:var, 1}, {:call, __MODULE__, :noop, [3]}},
    {:set, {:var, 1}, {:call, __MODULE__, :noop, [4]}},
    {:set, {:var, 1}, {:call, __MODULE__, :noop, [5]}},
  ]

  defp command_crash_seq, do: [
    {:set, {:var, 1}, {:call, __MODULE__, :noop, [0]}},
    {:set, {:var, 2}, {:call, __MODULE__, :noop, [1]}},
    {:set, {:var, 3}, {:call, __MODULE__, :noop, [2]}},
    {:set, {:var, 4}, {:call, __MODULE__, :noop, [3]}},
    {:set, {:var, 5}, {:call, __MODULE__, :crash_command, []}},
    {:set, {:var, 6}, {:call, __MODULE__, :noop, [4]}},
    {:set, {:var, 7}, {:call, __MODULE__, :noop, [5]}},
  ]

  defp precond_crash_seq, do: [
    {:set, {:var, 1}, {:call, __MODULE__, :noop, [0]}},
    {:set, {:var, 2}, {:call, __MODULE__, :noop, [1]}},
    {:set, {:var, 3}, {:call, __MODULE__, :noop, [2]}},
    {:set, {:var, 4}, {:call, __MODULE__, :noop, [3]}},
    {:set, {:var, 5}, {:call, __MODULE__, :crash_precond, []}},
    {:set, {:var, 6}, {:call, __MODULE__, :noop, [4]}},
    {:set, {:var, 7}, {:call, __MODULE__, :noop, [5]}},
  ]

  defp precond_fail_seq, do: [
    {:set, {:var, 1}, {:call, __MODULE__, :noop, [0]}},
    {:set, {:var, 2}, {:call, __MODULE__, :noop, [1]}},
    {:set, {:var, 3}, {:call, __MODULE__, :noop, [2]}},
    {:set, {:var, 4}, {:call, __MODULE__, :noop, [3]}},
    {:set, {:var, 5}, {:call, __MODULE__, :fail_precond, []}},
    {:set, {:var, 6}, {:call, __MODULE__, :noop, [4]}},
    {:set, {:var, 7}, {:call, __MODULE__, :noop, [5]}},
  ]

  defp postcond_crash_seq, do: [
    {:set, {:var, 1}, {:call, __MODULE__, :noop, [0]}},
    {:set, {:var, 2}, {:call, __MODULE__, :noop, [1]}},
    {:set, {:var, 3}, {:call, __MODULE__, :noop, [2]}},
    {:set, {:var, 4}, {:call, __MODULE__, :noop, [3]}},
    {:set, {:var, 5}, {:call, __MODULE__, :crash_postcond, []}},
    {:set, {:var, 6}, {:call, __MODULE__, :noop, [4]}},
    {:set, {:var, 7}, {:call, __MODULE__, :noop, [5]}},
  ]

  defp postcond_fail_seq, do: [
    {:set, {:var, 1}, {:call, __MODULE__, :noop, [0]}},
    {:set, {:var, 2}, {:call, __MODULE__, :noop, [1]}},
    {:set, {:var, 3}, {:call, __MODULE__, :noop, [2]}},
    {:set, {:var, 4}, {:call, __MODULE__, :noop, [3]}},
    {:set, {:var, 5}, {:call, __MODULE__, :fail_postcond, []}},
    {:set, {:var, 6}, {:call, __MODULE__, :noop, [4]}},
    {:set, {:var, 7}, {:call, __MODULE__, :noop, [5]}},
  ]

  defp strip_ansi_sequences(str) do
    r = ~r/\e\[.*?m/
    Regex.replace(r, str, "")
  end
end
