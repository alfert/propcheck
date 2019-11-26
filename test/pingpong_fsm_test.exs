defmodule PropCheck.Test.PingPongFSM do
  @moduledoc """
  Similar to `PingPongStateM`, but this time depending on the FSM module to
  understand the difference between both approaches.
  """

  use PropCheck.FSM
  use PropCheck, default_opts: &PropCheck.TestHelpers.config/0
  use ExUnit.Case
  import PropCheck.TestHelpers, except: [config: 0]
  alias PropCheck.Test.PingPongMaster
  require Logger
  @moduletag capture_log: true

  property "ping-pong FSM works properly" do
    numtests(1_000, forall cmds in commands(__MODULE__) do
      trap_exit do
        kill_all_player_processes()
        {:ok, _pid} = PingPongMaster.start_link()
        # :ok = :sys.install(PingPongMaster, {&log_message/3, :no_state})
        # :ok = :sys.trace(PingPongMaster, true)
        r = run_commands(__MODULE__, cmds)
        {history, state, result} = r
        # {:ok, messages} = :sys.log(PingPongMaster, :get)
        PingPongMaster.stop
        # Logger.info "Property finished. result is: #{inspect r}"
        # IO.puts "Property finished. result is: #{inspect r}"
        (result == :ok)
        # |> aggregate(command_names cmds)
        |> when_fail(
            IO.puts """
            History: #{inspect history, pretty: true}
            State: #{inspect state, pretty: true}
            Result: #{inspect result, pretty: true}
            """)
      end
    end)
  end

  defp log_message(log_state, {:in, msg}, proc_state) do
    Logger.debug(fn ->
      "Got message #{inspect msg, :pretty} in state #{inspect proc_state, :pretty}"
    end)
    log_state
  end
  defp log_message(log_state, {:in, msg, client}, proc_state) do
    Logger.debug(fn ->
      "Got message #{inspect msg, :pretty} from client #{inspect client} in state #{inspect proc_state, :pretty}"
    end)
    log_state
  end
  defp log_message(log_state, {:out, msg, client}, proc_state) do
    Logger.error(fn ->
      "Send message #{inspect msg, :pretty} to client #{inspect client} in state #{inspect proc_state, :pretty}"
    end)
    log_state
  end
  defp log_message(log_state, any, proc_state) do
    Logger.debug(fn ->
      "Got unknown message #{inspect any, :pretty} in state #{inspect proc_state, :pretty}"
    end)
    log_state
  end

  # State is modelled as tuples of `{state_name, state}`
  defstruct players: [], scores: %{}

  @max_players 100
  @players 1..@max_players |> Enum.map(&("player_#{&1}") |> String.to_atom)

  def initial_state, do: :empty_state
  def initial_state_data, do: %__MODULE__{}

  def empty_state(_) do
    [{:player_state, {:call, PingPongMaster, :add_player, [oneof(@players)]}}]
  end

  def player_state(s = %__MODULE__{players: [last_player]}) do
    empty_state(s) ++ play_games(s) ++ [
      {:player_state, {:call, PingPongMaster, :get_score, [last_player]}},
      {:empty_state, {:call, PingPongMaster, :remove_player, [last_player]}},
    ]
  end
  def player_state(s = %__MODULE__{players: ps}) do
    empty_state(s) ++ play_games(s) ++ [
      {:player_state, {:call, PingPongMaster, :get_score, [oneof ps]}},
      {:player_state, {:call, PingPongMaster, :remove_player, [oneof ps]}},
    ]
  end

  defp play_games(%__MODULE__{players: ps}) do
    [:play_ping_pong, :play_tennis, :play_football]
    |> Enum.map(fn f -> {:history, {:call, PingPongMaster, f, [oneof ps]}} end)
  end

  # no specific preconditions
  def precondition(_from, _target, _state, {:call, _m, _f, _a}), do: true

  # imprecise get_score due to async play-functions
  def postcondition(_from, _target, %__MODULE__{scores: scores},
                    {:call, _, :get_score, [player]}, res) do
    res <= scores[player]
  end
  def postcondition(_f, _t, _s, {:call, _m, :add_player, _a}, :ok), do: true
  def postcondition(:player_state, _t, _s, {:call, _m, :remove_player, _a}, {:removed, _}), do: true
  def postcondition(:player_state, _t, _s, {:call, _m, :play_ping_pong, _a}, :ok), do: true
  def postcondition(:player_state, _t, _s, {:call, _m, :play_tennis, _a}, :maybe_later), do: true
  def postcondition(:player_state, _t, _s, {:call, _m, :play_football, _a}, :no_way), do: true
  def postcondition(:player_state, _t, _s, {:call, _m, :play_ping_pong, _a}, {:dead_player, _}), do: true
  def postcondition(:player_state, _t, _s, {:call, _m, :play_tennis, _a}, {:dead_player, _}), do: true
  def postcondition(:player_state, _t, _s, {:call, _m, :play_football, _a}, {:dead_player, _}), do: true
  def postcondition(_from, _target, _state, {:call, _m, _f, _a}, _res), do: false

  # state data is updates for adding, removing, playing.
  def next_state_data(_from, :player_state, state, _res, {:call, _m, :add_player, [p]}) do
    if Enum.member?(state.players, p) do
      state
    else
      %__MODULE__{state |
          players: [p | state.players],
          scores: Map.put_new(state.scores, p, 0)
        }
    end
  end
  def next_state_data(:player_state, _target, state, _res, {:call, _, :remove_player, [p]}) do
    if Enum.member?(state.players, p) do
      %__MODULE__{state |
          players: List.delete(state.players, p),
          scores: Map.delete(state.scores, p)
        }
    else
      state
    end
  end
  def next_state_data(:player_state, _target, state, _res, {:call, _, :play_ping_pong, [p]}) do
    if Enum.member?(state.players, p) do
      %__MODULE__{state |
          scores: Map.update!(state.scores, p, fn v -> v + 1 end)}
    else
      state
    end
  end
  def next_state_data(_from, _target, state, _res, _call), do: state

  # ensure all player processes are dead
  defp kill_all_player_processes do
    Process.registered
    |> Enum.filter(&(Atom.to_string(&1) |> String.starts_with?("player_")))
    |> Enum.each(fn name ->
      pid = Process.whereis(name)
      if is_pid(pid) and Process.alive?(pid) do
        try do
          Process.exit(pid, :kill)
        catch
          _what, _value -> Logger.debug(fn -> "Already killed process #{name}" end)
        end
      end
    end)
  end

end
