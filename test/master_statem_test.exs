defmodule PropCheck.Test.MasterStateM do
  @moduledoc """
  Defines the state machine for the ping pong master. The properties
  are called from the test script `ping_pong_test.exs`.
  """

  use PropCheck
  use PropCheck.StateM
  use ExUnit.Case
  alias PropCheck.Test.PingPongMaster
  @moduletag capture_log: true

  property "master works fine", [:verbose, max_size: 100] do
    forall cmds <- more_commands(100, commands(__MODULE__)) do
      trap_exit do
        kill_all_player_processes()
        PingPongMaster.start_link()
        r = run_commands(__MODULE__, cmds)
        {history, state, result} = r
        PingPongMaster.stop
        # IO.puts "Property finished. result is: #{inspect r}"
        (result == :ok)
        |> when_fail(
            IO.puts """
            History: #{inspect history, pretty: true}
            State: #{inspect state, pretty: true}
            Result: #{inspect result, pretty: true}
            """)
        |> aggregate(command_names cmds)
        |> collect(length cmds)
      end
    end
  end

  # ensure all player processes are dead
  defp kill_all_player_processes do
    require Logger
    Process.registered
    |> Enum.filter(&(Atom.to_string(&1) |> String.starts_with?("player_")))
    |> Enum.each(fn name ->
      pid = Process.whereis(name)
      # nice idea from José Valim: Monitor the process ...
      ref = Process.monitor(name)
      if is_pid(pid) and Process.alive?(pid) do
        try do
          Process.exit(pid, :kill)
        catch
          _what, _value -> Logger.debug(fn -> "Already killed process #{name}" end)
        end
      end
      # ... and wait for the DOWN message.
      receive do
        {:DOWN, ^ref, :process, _object, _reason} -> :ok
      end
    end)
  end

  #####################################################
  ##
  ## Value Generators
  ##
  #####################################################
  @max_players 100
  @players 1..@max_players |> Enum.map(&("player_#{&1}") |> String.to_atom)

  def name, do: oneof @players

  def command(players) do
    if (Enum.count(players) > 0) do
      player_list = players |> MapSet.to_list
      oneof([
        {:call, PingPongMaster, :add_player, [name()]},
        {:call, PingPongMaster, :remove_player, [oneof(player_list)]},
        {:call, PingPongMaster, :get_score, [oneof(player_list)]}
        ])
    else
      {:call, PingPongMaster, :add_player, [name()]}
    end
  end

  #####################################################
  ##
  ## The state machine: We test registering, our model
  ## is a set of registered names.
  ##
  #####################################################

  @doc "initial model state of the state machine"
  def initial_state, do: MapSet.new

  @doc """
  Update the model state after a successful call. The `state` parameter has
  the value of before the call, `value` is the return value of the `call`, such
  that the new state can depend on the old state and the returned value.
  """
  def next_state(state, _value, {:call, PingPongMaster, :add_player, [name]}) do
    #IO.puts "next_state: add player #{name} in model #{inspect state}"
    state |> MapSet.put(name)
  end
  def next_state(state, _value, {:call, PingPongMaster, :remove_player, [name]}) do
    #IO.puts "next_state: remove player #{name} in model #{inspect state}"
    s = state |> MapSet.delete(name)
    #IO.puts "next_state: the new state is #{inspect s}"
    s
  end
  def next_state(state, _value, _call), do: state

  @doc "can the call in the current state be made?"
  def precondition(players, {:call, PingPongMaster, :remove_player, [name]}) do
    players |> MapSet.member?(name)
  end
  def precondition(_state, _call),  do: true

  @doc """
  Checks that the model state after the call is proper. The `state` is
  the state *before* the call, the `call` is the symbolic call and `r`
  is the result of the actual call.
  """
  def postcondition(players, {:call, PingPongMaster, :remove_player, [name]}, _r = {:removed, n}) do
    # IO.puts "postcondition: remove player #{name} => #{inspect r} in state: #{inspect players}"
    (name == n) and (players |> MapSet.member?(name))
  end
  def postcondition(_players, {:call, PingPongMaster, :get_score, [_name]}, score) do
    score == 0
  end
  def postcondition(_state, _call, _result), do: true

end
