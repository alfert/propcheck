defmodule PropertiesDefaultOptsFunctionTest do
  alias PropCheck.Test
  use ExUnit.Case
  use PropCheck, default_opts: &DefaultOpts.config/0

  property "default_opts function returns options", [max_size: 1] do
    assert_received :default_opts_is_ran
    assert Process.get(:property_opts) == [max_size: 1, numtests: 1]
  end
end
