defmodule CheckCounterExample do
  @moduledoc false
  alias PropCheck.CounterStrike

  def check(mfa) do
    CounterStrike.counter_example(mfa)
  end
end

defmodule StoreCounterExample.ModuleTag do
  use ExUnit.Case
  use PropCheck
  @moduletag store_counter_example: false

  setup_all do
    on_exit fn ->
      assert :none == CheckCounterExample.check({__MODULE__, :"property failing", []})
    end
  end

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

  setup_all do
    on_exit fn ->
      assert :none == CheckCounterExample.check({__MODULE__, :"property failing", []})
    end
  end

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

  setup_all do
    on_exit fn ->
      assert :none == CheckCounterExample.check({__MODULE__, :"property failing", []})
    end
  end

  @tag store_counter_example: false
  @tag will_fail: true
  property "failing" do
    forall n <- integer(0, :inf) do
      n < 0
    end
  end
end
