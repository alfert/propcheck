defmodule VerifyExceptionDetectionTest do
  # Tests to check that exception detection works as intended.
  use ExUnit.Case
  use PropCheck

  @moduletag :will_fail # must be run manually

  @tests [:failing_raise, :failing_throw, :failing_assert]
  @modes %{
    "default" => [],
    "detection disabled locally" => [{:detect_exceptions, false}],
    "detection enabled locally" => [{:detect_exceptions, true}]
  }

  def failing_raise do
    forall _ <- nat() do
      raise "raise-fail"
    end
  end

  def failing_throw() do
    forall _ <- nat() do
      throw "throw-fail"
    end
  end

  def failing_assert do
    forall n <- nat() do
      assert n <= 0
    end
  end

  for {mode, opts} <- @modes do
    describe mode do
      for test <- @tests do
        property "#{test}", opts do
          apply(__MODULE__, unquote(test), [])
        end
      end
    end
  end

  property "lengthy output?", [numtests: 10000] do
    forall n <- integer(1, :inf) do
      if n > 500 && rem(n, 2) == 0 do
        raise "#{n}"
      else
        true
      end
    end
  end
end
