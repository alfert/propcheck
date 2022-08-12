defmodule PropCheck.Test.BrokenTicketIssuerTest do
  use ExUnit.Case, async: true
  use PropCheck, default_opt: &PropCheck.TestHelpers.config/0
  use PropCheck.StateM

  @moduletag will_fail: true, manual: true

  property "broken ticket issuer", [:verbose] do
    forall cmds <- parallel_commands(__MODULE__) do
      {:ok, pid} = Agent.start_link(fn -> 0 end)
      Process.register(pid, Counter)
      {_seq_history, _par_state, result} = run_parallel_commands(__MODULE__, cmds)
      Agent.stop(pid)
      result == :ok
    end
  end

  def inc() do
    x = Agent.get(Counter, & &1)
    Agent.update(Counter, fn _ -> x + 1 end)
    x
  end

  def initial_state() do
    0
  end

  def command(_state) do
    oneof([
      {:call, __MODULE__, :inc, []}
    ])
  end

  def next_state(state, _res, {:call, __MODULE__, :inc, []}) do
    state + 1
  end

  def postcondition(state, {:call, __MODULE__, :inc, []}, res) do
    state == res
  end

  def precondition(_state, {:call, __MODULE__, :inc, []}) do
    true
  end
end
