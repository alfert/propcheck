defmodule VerifyVerboseElixirSyntaxTest do
  @moduledoc """
  Verifies the verbose syntax
  """
  use ExUnit.Case, async: false
  use PropCheck, default_opts: [:verbose]

  @moduletag :will_fail

  property "linked process crashes" do
    trap_exit(forall n <- nat() do
      # this must fail
      _pid = spawn_link(fn() -> n / 0 end)
      # wait for arrivial of the dieing linked process signal
      :timer.sleep(50)
      false
    end)
  end

  property "linked process kills it self" do
    trap_exit(forall _n <- nat() do
               # this must fail
               _pid = spawn_link(fn() -> Process.exit(self(), :kill) end)
               # wait for arrivial of the dieing linked process signal
               :timer.sleep(50)
               true #
    end)
  end

  @tag :manual
  property "collect prints Elixir syntax" do
    forall _n <- nat() do
      collect(true, %{test: __MODULE__})
    end
  end

  property "exception was raised with stacktrace" do
    forall _x <- nat() do
      raise "test crash"
    end
  end
end
