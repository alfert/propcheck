#
# Tests to verify the behaviour of storing counter examples. These tests here
# intentionally fail, but no counter examples should be stored. In VerifyCounterExampleTest,
# we can verify that no test here resulted in a stored counter example.
#
defmodule StoreCounterExample.ModuleTag do
  use ExUnit.Case
  use PropCheck
  @moduletag store_counter_example: false, manual: true

  @tag will_fail: true
  property "failing" do
    forall n <- integer(0, :inf) do
      n < 0
    end
  end
end

defmodule StoreCounterExample.DescribeTag do
  use ExUnit.Case
  use PropCheck

  @moduletag manual: true

  describe "store counter example with describe" do
    @describetag store_counter_example: false

    @tag will_fail: true
    property "failing" do
      forall n <- integer(0, :inf) do
        n < 0
      end
    end
  end
end

defmodule StoreCounter.ExampleTag do
  use ExUnit.Case
  use PropCheck

  @moduletag manual: true

  @tag store_counter_example: false
  @tag will_fail: true
  property "failing" do
    forall n <- integer(0, :inf) do
      n < 0
    end
  end
end
