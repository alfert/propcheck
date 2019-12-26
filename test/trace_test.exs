defmodule PropCheck.TracingTest do
  @moduledoc """
  Tests for Tracing sequences
  """
  use ExUnit.Case, async: true

  use PropCheck, default_opts: &PropCheck.TestHelpers.config/0
  import PropCheck.TestHelpers, except: [config: 0]
  alias PropCheck.Tracer.Scheduler

  defmodule TracedModule do
    use PropCheck.Tracer.Instrument

    def hi, do: :hello

    def put_hello do
      IO.puts "Putting the hello"
      send(self(), hi())
    end

    def get_hello do
      receive do
        :hello -> IO.puts "Received hello"
          :get_hello
      end
    end
  end

  test "Receive the hello sequence" do
    Scheduler.start_link()
    TracedModule.put_hello()
    assert :get_hello == TracedModule.get_hello()
  end

  def mapped_queue do
    let l <- non_empty(list(nat())) do
      map = Enum.reduce(l, %{}, fn e, m -> Scheduler.add_msg(m, :source, :dest, e) end)
      {:source, :dest, l, map}
    end
  end

  property "same amounf of entries in the queue and list" do
    forall {s, d, l, m} <- mapped_queue() do
      assert l == (Map.get(m, {s, d}, :queue.new) |> :queue.to_list )
    end
  end

  property "head of queue and list are the same" do
    forall {s, d, l, m} <- mapped_queue() do
      {m1, {_k, msg}} = Scheduler.get_msg(m, {s, d})
      assert msg == hd(l)
      assert Map.has_key?(m1, {s, d}) == (length(l) > 1)
    end
  end

end
