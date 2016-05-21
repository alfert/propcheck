defmodule PropCheck.Test.PingPongTest do

  use ExUnit.Case
  import PropCheck
  @moduletag capture_log: true

  prop_test(PropCheck.Test.MasterStateM)

  prop_test(PropCheck.Test.PingPongStateM)

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
