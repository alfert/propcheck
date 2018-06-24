defmodule PropCheck.Test.CounterDSL do
  @moduledoc """
  This is a test of the modulo counter. There are several variants of test
  setups, to check that the DSL implementation is capable of shrinking
  failures due to ignoring the modulo features to a minimal set of steps.

  The statemachine model of the counter has only three states:
      * `init`: the counter is initialized
      * `zero`: the counter is reset to `0`
      * `one`: the counter has a value above `0`

  These states are reflected in the commands and for determining the
  weights of the commands.
  """
  use PropCheck
  use PropCheck.StateM.DSL
  use ExUnit.Case
  require Logger

  alias PropCheck.Test.Counter

  @moduletag capture_log: true

  #########################################################################
  ### The properties
  #########################################################################

  property "infinity counter works fine", [:verbose] do
    forall cmds <- commands(__MODULE__) do
      trap_exit do
        {:ok, _pid} = Counter.start_link()
        events = run_commands(cmds)
        Counter.stop()

        (events.result == :ok)
        |> when_fail(
            IO.puts """
            History: #{inspect events.history, pretty: true}
            State: #{inspect events.state, pretty: true}
            Env: #{inspect events.env, pretty: true}
            Result: #{inspect events.result, pretty: true}
            """)
        |> aggregate(command_names cmds)
        |> measure("length of commands", length(cmds))
      end
    end
  end

  property "modulo counter does not increment inifinite times", [:verbose] do
    forall cmds <- commands(__MODULE__) do
      trap_exit do
        {:ok, _pid} = Counter.start_link(5)
        events = run_commands(cmds)
        Counter.stop()

        (events.result == :ok)
        # |> fails()
        |> when_fail(
            IO.puts """
            History: #{inspect events.history, pretty: true}
            State: #{inspect events.state, pretty: true}
            Env: #{inspect events.env, pretty: true}
            Result: #{inspect events.result, pretty: true}
            """)
        |> aggregate(command_names cmds)
        |> measure("length of commands", length(cmds))

      end
    end
  end
  #########################################################################
  ### The model
  #########################################################################

  def initial_state(), do: :init

  def weight(:init), do: [inc: 1, clear: 1]
  def weight(_), do: [get: 1, inc: 2, clear: 1]

  defcommand :inc do
    def impl(), do: Counter.inc()
    def args(_), do: fixed_list([])
    def next(:init, [], _res), do: :zero
    def next(:zero, [], _res), do: :one
    def next(:one, [], _res), do: :one
    def post(:init, [], res), do: res == 0
    def post(:zero, [], res), do: res > 0
    def post(:one, [], res), do: res > 0
  end

  defcommand :get do
    def impl(), do: Counter.get()
    def args(_), do: fixed_list([])
    def post(_state, [], res), do: res >= 0
  end

  defcommand :clear do
    def impl(), do: Counter.clear()
    def args(_), do: fixed_list([])
    def next(_state, [], _res), do: :zero
    def post(_state, [], res), do: res == :ok
  end

end
