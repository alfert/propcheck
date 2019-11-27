defmodule VerifyCounterExampleTest do
  # The tests here verify that CheckCounterExamplesTest did indeed not store
  # any counter examples.
  use ExUnit.Case
  use PropCheck, default_opts: &PropCheck.TestHelpers.config/0

  @moduletag manual: true

  @modules [
    StoreCounterExample.ModuleTag,
    StoreCounterExample.DescribeTag,
    StoreCounterExample.ExampleTag
  ]

  for module <- @modules do
    test "no counter examples stored for #{module}" do
      assert :none ==
               PropCheck.CounterStrike.counter_example({unquote(module), ":property failing", []})
    end
  end
end
