defmodule PropCheck.Test.CounterStrikeTest do

  use ExUnit.Case
  use PropCheck
  require Logger

  alias PropCheck.CounterStrike

  setup do
    IO.puts "This is a setup callback for #{inspect self()}"
    filename = "counterstrike_test.#{System.unique_integer([:positive, :monotonic])}.dets"
    path = Path.join(Mix.Project.build_path(), filename)
    File.rm(path)
    {:ok, pid} = CounterStrike.start_link(path)
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

    {:ok, pid} = CounterStrike.start_link(path)
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

  property "often_failing" do
    Logger.debug "Lets ask counter_strike: #{CounterStrike.counter_example({:a, :b, []})}"
    forall l <- list(integer()) do
      l == List.reverse(l)
    end
  end
end
