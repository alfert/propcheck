defmodule PropCheck.Test.PingPongTest do
  @moduledoc """
  A test for a strange call sequence, which once troubled us.
  """
  use ExUnit.Case, async: false
  use PropCheck

  @moduletag capture_log: true

  alias PropCheck.Test.PingPongMaster

  # ensure all player processes are dead
  defp kill_all_player_processes do
    require Logger

    Process.registered()
    |> Enum.filter(&(Atom.to_string(&1) |> String.starts_with?("player_")))
    |> Enum.each(fn name ->
      # nice idea from José Valim: Monitor the process ...
      ref = Process.monitor(name)
      pid = Process.whereis(name)

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

  test "Strange Call Sequence" do
    PingPongMaster.start_link()
    PingPongMaster.add_player(:player_73)
    PingPongMaster.play_ping_pong(:player_73)
    PingPongMaster.play_ping_pong(:player_73)
    :timer.sleep(50)
    score = PingPongMaster.get_score(:player_73)
    PingPongMaster.stop()
    kill_all_player_processes()

    assert score <= 2
  end
end
