defmodule PropCheck.Test.CounterStrikeTest do

  @moduledoc """
  Tests for the handling counter examples.
  """
  use ExUnit.Case, async: true
  use PropCheck, default_opts: &PropCheck.TestHelpers.config/0
  import PropCheck.TestHelpers, only: [debugln: 1, config: 0]
  require Logger

  alias PropCheck.CounterStrike

  setup do
    debugln "This is a setup callback for #{inspect self()}"
    filename = "counterstrike_test.#{System.unique_integer([:positive, :monotonic])}.dets"
    path = Path.join(Mix.Project.build_path(), filename)
    File.rm(path)
    {:ok, pid} = CounterStrike.start_link(path, [])
    # on_exit(fn() -> File.rm!(path) end)
    {:ok, %{pid: pid, path: path}}
  end

  test "no files means no counter example", %{pid: pid} do
    assert :none == CounterStrike.counter_example(pid, {:foo, :bar, 0})
  end

  test "an existing files suggests counter examples", %{path: path, pid: org_pid} do
    assert :none == CounterStrike.counter_example(org_pid, {:foo, :bar, 0})
    assert :ok = CounterStrike.add_counter_example(org_pid, {:foo, :bar, 0}, [])
    ref = Process.monitor(org_pid)
    CounterStrike.stop(org_pid)
    wait_for_stop(ref)

    {:ok, pid} = CounterStrike.start_link(path, [])
    assert :others == CounterStrike.counter_example(pid, {:foo, :bar, 1})
    assert {:ok, []} == CounterStrike.counter_example(pid, {:foo, :bar, 0})
    ref = Process.monitor(pid)
    CounterStrike.stop(pid)
    wait_for_stop(ref)
  end

  def wait_for_stop(ref) do
    receive do
      {:DOWN, ^ref, :process, _pid, _} -> :ok
    end
  end

  @tag will_fail: true
  property "often_failing" do
    Logger.debug(fn -> "Lets ask counter_strike: #{CounterStrike.counter_example({:a, :b, []})}" end)
    forall l <- list(integer()) do
      l == Enum.reverse(l)
    end
  end

  defmodule Helper do
    @moduledoc """
    Helper for "PropEr error is not stored" test, can't be inside the tests
    because it triggers strange error in ExUnit when `async` is true and
    `--trace` options is enabled. Bug is already fixed in Elixir master
    """
    use ExUnit.Case
    use PropCheck, default_opts: &PropCheck.TestHelpers.config/0

    @tag will_fail: true # must be run manually
    property "cant_generate" do
      # Check that no counterexample is stored if PropEr reported an error
      gen = such_that b <- false, when: b
      forall b <- gen do
        b
      end
    end
  end

  test "PropEr error is not stored" do
    # Check that an invalid counterexample is not stored. PropEr returns
    # {:error, _} on internal errors such as inability to generate a
    # value instance. Such errors cannot be used as counterexamples in
    # subsequent runs.

    assert_raise ExUnit.AssertionError, ~r/cant_generate/, fn ->
      apply(Helper, :"property cant_generate", [[]])
    end

    # Run a second time to ensure that no counterexample was stored.
    assert_raise ExUnit.AssertionError, ~r/cant_generate/, fn ->
      apply(Helper, :"property cant_generate", [[]])
    end
  end
end
