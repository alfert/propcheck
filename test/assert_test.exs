defmodule AssertTest do
  use ExUnit.Case
  use PropCheck

  property "failing raise" do
    forall _ <- nat() do
      raise "fail"
    end
  end

  property "failing assert" do
    forall n <- nat() do
      assert n <= 0
    end
  end
end
