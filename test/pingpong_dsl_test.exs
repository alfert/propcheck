defmodule PropCheck.Test.PingPongDSL do
  @moduledoc """
  Applying the DSL for defining the state machine for property
  testing the ping player interaction.
  """

  use ExUnit.Case
  use PropCheck, default_opts: &PropCheck.TestHelpers.config/0
  use PropCheck.StateM.ModelDSL

  alias PropCheck.Test.PingPongMaster
  require Logger
  @moduletag capture_log: true

  property "DSL ping-pong player" do
    forall cmds <- commands(__MODULE__) do
      trap_exit do
        assert [] == player_processes()
        PingPongMaster.start_link()
        r = run_commands(__MODULE__, cmds)
        {_history, _state, result} = r
        :ok = PingPongMaster.stop()

        (result == :ok)
        |> when_fail(print_report(r, cmds))
      end
    end
  end

  @spec player_processes() :: [String.t]
  defp player_processes do
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
  def initial_state, do: %__MODULE__{}

    def command_gen(%__MODULE__{players: []}), do: {:add_player, [any_name()]}
    def command_gen(state) do
      oneof([
        {:add_player, [any_name()]},
        {:remove_player, [known_name(state)]},
        {:get_score, [known_name(state)]},
        {:play_ping_pong, [known_name(state)]},
        {:play_tennis, [known_name(state)]},
        {:play_football, [known_name(state)]},
      ])
    end

  #####################################################
  ##
  ## Value Generators
  ##
  #####################################################
  @max_players 100
  @players 1..@max_players
    |> Enum.map(&("player_#{&1}")
    |> String.to_atom)

  def any_name, do: elements @players
  def known_name(%__MODULE__{players: player_list}), do: elements player_list

  defcommand :add_player do
    def impl(name), do: PingPongMaster.add_player(name)
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
    def post(_state, [name], {:removed, n}), do: n == name
    def next(state = %__MODULE__{players: ps, scores: scores}, [name], _res) do
      state
      |> Map.put(:players, List.delete(ps, name))
      |> Map.put(:scores, Map.delete(scores, name))
    end
    def pre(%__MODULE__{players: ps}, [name]), do: Enum.member?(ps, name)
  end

  defcommand :play_ping_pong do
    def impl(name), do: PingPongMaster.play_ping_pong(name)
    def pre(%__MODULE__{players: ps}, [name]), do: Enum.member?(ps, name)
    def post(_state, [_name], result), do: result == :ok
    def next(state =  %__MODULE__{scores: scores}, [name], _res) do
      new_scores = Map.update!(scores, name, & (&1 + 1))
      Logger.debug(fn -> "New Scores are: #{inspect new_scores}" end)

      x = %__MODULE__{state | scores: new_scores}
      Logger.debug(fn -> "new state: #{inspect x}" end)
      x
    end
  end

  defcommand :play_tennis do
    def impl(name), do: PingPongMaster.play_tennis(name)
    def pre(%__MODULE__{players: ps}, [name]), do: Enum.member?(ps, name)
    def post(_state, [_name], result), do: result == :maybe_later
  end

  defcommand :play_football do
    def impl(name), do: PingPongMaster.play_football(name)
    def pre(%__MODULE__{players: ps}, [name]), do: Enum.member?(ps, name)
    def post(_state, [_name], result), do: result == :no_way
  end

  defcommand :get_score do
    def impl(name), do: PingPongMaster.get_score(name)
    def pre(%__MODULE__{players: ps}, [name]), do: Enum.member?(ps, name)
    def post(%__MODULE__{scores: scores}, [name], result) do
      # playing ping pong is asynchronous, therefore the counter in scores
      # might not be updated properly: our model is eager (and synchronous), but
      # the real machinery might be updated later
      result <= Map.fetch!(scores, name)
    end
  end
end
