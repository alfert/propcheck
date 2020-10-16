defmodule PropcheckTest do
  @moduledoc """
  Basic Tests for PropCheck, delegating mostly to doc tests.
  """
  use ExUnit.Case, async: true
  use PropCheck, default_opts: &PropCheck.TestHelpers.config/0

  import ExUnit.CaptureIO
  require Logger

  doctest(PropCheck)
  doctest(PropCheck.StateM)

  @moduletag capture_log: true

  @type my_stack(t) :: [t]
  @type tagged_stack(t) :: {:stack, [t]}

  test "let/2 generates larger lists of bindings" do
    let_gen = let [
      m <- nat(),
      n <- nat(),
      o <- nat()
    ] do
      [m, n, o]
      :ok
    end

    assert capture_io(fn ->
      quickcheck(
        forall x <- let_gen do
          equals(:ok, x)
        end
      )
    end) =~ "Passed"
  end

  test "equals/2 outputs on error" do
    assert capture_io(fn ->
      quickcheck(
        forall x <- :not_ok do
          equals(:ok, x)
        end
      )
    end) =~ ":ok != :not_ok"
  end

  test "sample_shrink/2" do
    assert capture_io(fn ->
      assert :ok == sample_shrink(1)
    end) == "1\n"

    assert capture_io(fn ->
      assert :ok == sample_shrink([1, 2, 3])
    end) == "[1,2,3]\n"
  end

  describe "forall" do
    test "can use assertion in forall" do
      assert capture_io(fn ->
        quickcheck(
          forall _x <- :not_ok, [:verbose] do
          assert false
          end
        )
        end) =~ "Expected truthy, got false"
    end

    test "can use assertion in forall without output" do
      refute capture_io(fn ->
        quickcheck(
          forall _x <- :not_ok, [:quiet] do
          assert false
          end
        )
        end) =~ "Expected truthy, got false"
    end

    property "can use let-like assignment in forall" do
      forall [
        m <- integer(),
        n <- integer()
      ] do
        is_integer(m) and is_integer(n)
      end
    end

    test "syntax errors are reported" do
      assert_raise ArgumentError, fn ->
        Code.compile_string("""
          use PropCheck

          forall [n operator nat()], do: true
        """) =~ "Usage:"
      end

      assert_raise ArgumentError, fn ->
        Code.compile_string("""
          use PropCheck

          forall {n <- nat()}, do: true
        """) =~ "Usage:"
      end
    end
  end

end
