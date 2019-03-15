defmodule PropertiesTest do
  use ExUnit.Case
  use PropCheck

  setup do
    [generator: nat()]
  end

  property "can use context", [], context do
    forall n <- context.generator do
      is_integer(n)
    end
  end

  property "can use let-like assignment" do
    forall [
      m <- integer(),
      n <- integer()
    ] do
      is_integer(m) and is_integer(n)
    end
  end
end
