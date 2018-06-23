defmodule PropCheck.Test.Counter do
  @moduledoc """
  An `Agent`-based counter as an example for a stateful system.

  It works a modulo-counter, the divisor is set at `start_link` with
  a default of `:infinity`, i.e. no modulo division of the counter.
  """

  use Agent

  @type reset_t :: pos_integer | :infinity

  @spec start_link() :: {:ok, pid}
  @spec start_link(atom) :: {:ok, pid}
  @spec start_link(atom) :: {:ok, pid}
  def start_link(reset \\:infinity, name \\ __MODULE__) do
    Agent.start_link(fn -> {-1, reset} end, name: name)
  end

  def stop(pid \\ __MODULE__) do
    Agent.stop(pid)
  end

  @spec clear() :: :ok
  @spec clear(pid) :: :ok
  def clear(pid \\ __MODULE__) do
    Agent.update(pid, fn {_, reset} -> {0, reset} end)
  end

  @spec get() :: integer
  @spec get(pid) :: integer
  def get(pid \\ __MODULE__) do
    Agent.get(pid, fn {count, _reset} -> count end)
  end

  @spec inc() :: :integer
  @spec inc(pid) :: :integer
  @spec inc(pos_integer, pid) :: :integer
  def inc(increment \\ 1, pid \\ __MODULE__) when increment > 0 do
    Agent.get_and_update(pid, fn
      {count, :infinity} ->
        new_count = count + increment
        {new_count, {new_count, :infinity}}
      {count, reset} ->
        new_count =Integer.mod(count + increment, reset)
        {new_count, {new_count, reset}}
    end)
  end
end
