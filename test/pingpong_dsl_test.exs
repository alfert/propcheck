defmodule PropCheck.Test.PingPongDSL do
  @moduledoc """
  Applying the  DSL for defining the state machine for property
  testing the ping player interaction.
  """

  use ExUnit.Case
  use PropCheck
  use PropCheck.StateM.DSL
  alias PropCheck.Test.PingPongMaster
  require Logger
  @moduletag capture_log: true

  property "DSL ping-pong player", [:verbose] do
    forall cmds <- commands(__MODULE__) do
      trap_exit do
        assert [] == player_processes()
        PingPongMaster.start_link()
        events = run_commands(cmds)
        :ok = PingPongMaster.stop()

        (events.result == :ok)
        |> when_fail(IO.puts """
        History: #{inspect events.history, pretty: true}
        State: #{inspect events.state, pretty: true}
        Result: #{inspect events.result, pretty: true}
        """)
        |> aggregate(command_names cmds)
      end
    end
  end

  @spec player_processes() :: [String.t]
  defp player_processes() do
    Process.registered
    |> Enum.filter(&(Atom.to_string(&1)
    |> String.starts_with?("player_")))
  end

  #####################################################
  ##
  ## The state machine: We test playing, our model
  ## is a set of registered names and their scores.
  ##
  #####################################################

  defstruct players: [], scores: %{}

  @doc "initial model state of the state machine"
  def initial_state(), do: %__MODULE__{}

  def weight(%__MODULE__{players: []}), do: [add_player: 1]
  def weight(_), do:
    [
      add_player: 1, remove_player: 1, get_score: 1,
      play_ping_pong: 1, play_tennis: 1, play_football: 1
    ]

  #####################################################
  ##
  ## Value Generators
  ##
  #####################################################
  @max_players 100
  @players 1..@max_players
    |> Enum.map(&("player_#{&1}")
    |> String.to_atom)

  def any_name(), do: elements @players
  def known_name(%__MODULE__{players: player_list}), do: elements player_list

  defcommand :add_player do
    def impl(name), do: PingPongMaster.add_player(name)
    def args(_state), do: fixed_list([any_name()])
    def post(_state, [_name], result), do: result == :ok
    def next(state = %__MODULE__{players: ps, scores: scores}, [name], _result) do
      if Enum.member?(ps, name) do
        state
      else
        %__MODULE__{state |
          players: [name | ps],
          scores: Map.put(scores, name, 0)
        }
      end
    end
  end

  defcommand :remove_player do
    def impl(name), do: PingPongMaster.remove_player(name)
    def args(state), do: fixed_list([known_name(state)])
    def post(_state, [name], {:removed, n}), do: n == name
    def next(state = %__MODULE__{players: ps, scores: scores}, [name], _res) do
      state
      |> Map.put(:players, List.delete(ps, name))
      |> Map.put(:scores, Map.delete(scores, name))
    end
    def pre(%__MODULE{players: ps}, [name]), do: Enum.member?(ps, name)
  end

  defcommand :play_ping_pong do
    def impl(name), do: PingPongMaster.play_ping_pong(name)
    def args(state), do: fixed_list([known_name(state)])
    def pre(%__MODULE__{players: ps}, [name]), do: Enum.member?(ps, name)
    def post(_state, [_name], result), do: result == :ok
    def next(state =  %__MODULE__{scores: scores}, [name], _res) do
      new_scores = Map.update!(scores, name, & (&1 + 1))
      Logger.debug "New Scores are: #{inspect new_scores}"
      # x = put_in(state, :scores, new_scores)
      x = %__MODULE__{state | scores: new_scores}
      Logger.debug "new state: #{inspect x}"
      x
    end
  end

  defcommand :play_tennis do
    def impl(name), do: PingPongMaster.play_tennis(name)
    def args(state), do: fixed_list([known_name(state)])
    def pre(%__MODULE__{players: ps}, [name]), do: Enum.member?(ps, name)
    def post(_state, [_name], result), do: result == :maybe_later
  end

  defcommand :play_football do
    def impl(name), do: PingPongMaster.play_football(name)
    def args(state), do: fixed_list([known_name(state)])
    def pre(%__MODULE__{players: ps}, [name]), do: Enum.member?(ps, name)
    def post(_state, [_name], result), do: result == :no_way
  end

  defcommand :get_score do
    def impl(name), do: PingPongMaster.get_score(name)
    def args(state), do: fixed_list([known_name(state)])
    def pre(%__MODULE__{players: ps}, [name]), do: Enum.member?(ps, name)
    def post(%__MODULE__{scores: scores}, [name], result) do
      # playing ping pong is asynchronuous, therefore the counter in scores
      # might not be updated properly: our model is eager (and synchronous), but
      # the real machinery might be updated later
      result <= Map.fetch!(scores, name)
    end
  end
end
