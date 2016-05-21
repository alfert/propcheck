defmodule PropCheck.Test.PingPongTest do

  use ExUnit.Case
  import PropCheck
  @moduletag capture_log: true

  prop_test(PropCheck.Test.MasterStateM)
  prop_test(PropCheck.Test.PingPongStateM)

end
