defmodule PropCheck.Test.PingPongTest do

  use ExUnit.Case, async: false
  use PropCheck

  @moduletag capture_log: true


  # ensure all player processes are dead
  defp kill_all_player_processes() do
    require Logger
    Process.registered
    |> Enum.filter(&(Atom.to_string(&1) |> String.starts_with?("player_")))
    |> Enum.each(fn name ->
      pid = Process.whereis(name)
      if is_pid(pid) and Process.alive?(pid) do
        try do
          Process.exit(pid, :kill)
        catch
          _what, _value -> Logger.debug "Already killed process #{name}"
        end
      end
    end)
  end


  test "Strange Call Sequence" do
    PropCheck.Test.PingPongMaster.start_link
    PropCheck.Test.PingPongMaster.add_player :player_73
    PropCheck.Test.PingPongMaster.play_ping_pong :player_73
    PropCheck.Test.PingPongMaster.play_ping_pong :player_73
    :timer.sleep(50)
    score = PropCheck.Test.PingPongMaster.get_score :player_73
    PropCheck.Test.PingPongMaster.stop

    assert score <= 2
  end

end
