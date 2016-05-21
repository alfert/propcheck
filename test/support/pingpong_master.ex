defmodule PropCheck.Test.PingPongMaster do
  @moduledoc """
  This is the ping pong master from Proper's Process Interaction Tutorial,
  translated from Erlang to Elixir.
  """

  use GenServer
  require Logger
  
  def start_link() do
    GenServer.start_link(__MODULE__, [], name: PingPongMaster)
  end

  def stop() do
    GenServer.cast(PingPongMaster, :stop)
  end

  def add_player(name) do
    GenServer.call(PingPongMaster, {:add_player, name})
  end

  def remove_player(name) do
    GenServer.call(PingPongMaster, {:remove_player, name})
  end

  def ping(from_name) do
    GenServer.call(PingPoingMaster, {:ping, from_name})
  end

  def get_score(name) do
    GenServer.call(PingPongMaster, {:get_score, name})
  end

  @doc "Process loop for the ping pong player process"
  def ping_pong_player(name) do
    receive do
      :ping_pong        -> :pong = ping(name)
      {:tennis, from}   -> send(from, :maybe_later)
      {:football, from} -> send(from, :no_way)
    end
    ping_pong_player(name)
  end

  @doc "Start playing ping pong"
  def play_ping_pong(player) do
    send(player, :ping_pong)
    :ok
  end

  @doc "Start playing football"
  def play_football(player) do
    send(player, {:football, self})
    receive do
      reply -> reply
      after 500 -> "Football timeout!"
    end
  end

  @doc "Start playing tennis"
  def play_tennis(player) do
    send(player, {:tennis, self})
    receive do
      reply -> reply
      after 500 -> "Tennis timeout!"
    end
  end


  ######################################################################

  def init([]) do
    {:ok, HashDict.new}
  end

  def handle_cast(:stop, scores) do
    {:stop, :normal, scores}
  end

  def handle_call({:add_player, name}, _from, scores) do
    case Process.whereis(name) do
      nil ->
          pid = spawn(fn() -> ping_pong_player(name) end)
          true = Process.register(pid, name)
          {:reply, :ok, scores |> Dict.put(name, 0)}
      pid when is_pid(pid) ->
          Logger.debug "add_player: player #{name} already exists!"
          {:reply, :ok, scores}
    end
  end
  def handle_call({:remove_player, name}, _from, scores) do
    pid = case Process.whereis(name) do
      nil -> Logger.debug("Process #{name} is unknown / not running")
        true == is_pid(nil)
      pid -> pid
    end
    if Process.alive? pid do
      Process.exit(pid, :kill)
    else
      Logger.debug "player #{name} with pid #{pid} is not alive any longer"
    end
    {:reply, {:removed, name}, scores |> Dict.delete(name)}
  end
  def handle_call({:ping, from_name}, _from, scores) do
    if (scores |> Dict.has_key?(from_name)) do
      {:reply, :pong, scores |> Dict.update!(from_name, &(&1 + 1))}
    else
      {:reply, {:removed, from_name}, scores}
    end
  end
  def handle_call({:get_score, name}, _from, scores) do
    {:reply, scores |> Dict.fetch!(name), scores}
  end

  @doc "Terminates all clients"
  def terminate(_reason, scores) do
    scores
      |> Dict.keys
      |> Enum.each(&(case Process.whereis(&1) do
          nil -> "Process #{&1} does not exist"
          pid -> pid |> Process.exit(:kill)
        end))
  end
end
