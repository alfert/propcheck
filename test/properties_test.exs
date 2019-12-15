defmodule PropertiesTest do
  use ExUnit.Case, async: true
  use PropCheck, default_opts: [numtests: 1]

  setup do
    [generator: nat()]
  end

  property "can use context", [], context do
    forall n <- context.generator do
      is_integer(n)
    end
  end

  property "default options are set", [max_size: 1] do
    opts = Process.get(:property_opts)
    assert {:max_size, 1} in opts
    assert {:numtests, 1} in opts
  end

  # This will be filtered with `--exclude not_implemented`.
  property "not yet implemented"
end
