defmodule PropCheck.TracingTest do
  @moduledoc """
  Tests for Tracing sequences
  """
  use ExUnit.Case, async: true

  use PropCheck, default_opts: &PropCheck.TestHelpers.config/0
  import PropCheck.TestHelpers, except: [config: 0]

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
    GenServer.start_link(PropCheck.Tracer.Scheduler, :nothing, name: PropCheck.Tracer.Scheduler)
    TracedModule.put_hello()
    assert :get_hello == TracedModule.get_hello()
  end

end
