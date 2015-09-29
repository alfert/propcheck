defmodule PropCheck.Test.PingPongTest do

  use ExUnit.Case
  import PropCheck

  prop_test(PropCheck.Test.MasterStateM)

end
