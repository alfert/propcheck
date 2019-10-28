defmodule PropCheck.DeriveGenerators.ExpandTest do
  use ExUnit.Case

  alias PropCheck.DeriveGenerators.Expand
  alias PropCheck.DeriveGenerators.NotSupported

  describe "Unsupported" do
    test "none" do
      assert_raise NotSupported, fn ->
        Expand.expand({:type, {"nones", {:type, 10, :none, []}, 0}})
      end
    end

    test "pids" do
      assert_raise NotSupported, fn ->
        Expand.expand({:type, {"pids", {:type, 10, :pid, []}, 0}})
      end
    end

    test "ports" do
      assert_raise NotSupported, fn ->
        Expand.expand({:type, {"ports", {:type, 10, :port, []}, 0}})
      end
    end

    test "references" do
      assert_raise NotSupported, fn ->
        Expand.expand({:type, {"references", {:type, 10, :reference, []}, 0}})
      end
    end

    test "no_return" do
      assert_raise NotSupported, fn ->
        Expand.expand({:type, {"no_returns", {:type, 10, :no_return, []}, 0}})
      end
    end

    test "identifier" do
      assert_raise NotSupported, fn ->
        Expand.expand({:type, {"identifiers", {:type, 10, :identifier, []}, 0}})
      end
    end

    test "funs" do
      assert_raise NotSupported, fn ->
        Expand.expand({:type, {"funs", {:type, 10, :fun, []}, 0}})
      end

      assert_raise NotSupported, fn ->
        Expand.expand({:type, {"functions", {:type, 10, :function, []}, 0}})
      end
    end

    test "iolist" do
      assert_raise NotSupported, fn ->
        Expand.expand({:type, {"iolists", {:type, 10, :iolist, []}, 0}})
      end
    end

    test "iodata" do
      assert_raise NotSupported, fn ->
        Expand.expand({:type, {"iodatas", {:type, 10, :iodata, []}, 0}})
      end
    end
  end
end
