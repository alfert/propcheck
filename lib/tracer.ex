defmodule PropCheck.Tracer do
  @moduledoc """
  Provides the tracer subsystem of PropCheck, an independent implementation of
  the QuickChecks Pulse ideas.
  """

  defmodule TraceDecorator do
    @moduledoc """
    Defines the decorator callback.
    """
    use Decorator.Define, [trace: 0]

    def trace(body, context), do: PropCheck.Tracer.Instrument.instrument(body, context)
  end

  defmodule Instrument do
    @moduledoc """
    This module provides the replacements for message handling and process spawning,
    interacting with the central scheduler.
    """
    defp scheduler, do: PropCheck.Tracer.Scheduler

    IO.puts("Instrument: all loaded applications: #{inspect Application.loaded_applications()}")
    if Enum.any?(Application.loaded_applications(), fn {app, _, _} -> app == :mix end) do
      IO.puts "Mix is running in mode #{inspect Mix.env}"
    else
      IO.puts "Mix is not running"
    end

    defmacro __using__(_opts) do
      quote do
        import Kernel, except: [send: 2, spawn: 1]
        use PropCheck.Tracer.TraceDecorator
        defdelegate send(m, d), to: PropCheck.Tracer.Instrument
        defdelegate spawn(f), to: PropCheck.Tracer.Instrument
        @decorate_all trace()
      end
    end

    @doc """
    Replacement for ordinary message send: Send the message to the central scheduler
    """
    def send(dest, message) do
      Kernel.send(scheduler(), {:send, self(), dest, message})
      message
    end

    @doc """
    New function to allow a process to explicitely give up control to the scheduler.
    This one is required to handle
    """
    def yield do
      sched = scheduler()
      Kernel.send(sched, {:yield, self()})
      receive do
        {^sched, :go} -> :ok
      end
    end

    @doc """
    Spawns a new function, that waits for scheduler sending a `:go` to move forward.
    """
    def spawn(fun) do
      sched = scheduler()
      pid = Kernel.spawn(fn ->
        receive do
          {^sched, :go} -> fun.()
        end
      end)
      Kernel.send(scheduler(), {:spawned, pid})
      pid
    end

    @doc """
    Instruments the body of a function to handle the `receive do ... end` expression
    for Tracer
    """
    def instrument(expr, context) do
      IO.puts "instrument function #{context.name}"
      instr_expr = Macro.postwalk(expr, fn
        {:receive, _info, [patterns]} -> # identify do: patterns Und after: clause, diese müssen bei
          # gen_receive als Argument übernommen werden.
          IO.puts "instrument receive with pattern #{Macro.to_string patterns}"
          IO.puts "instrument receive with pattern #{inspect patterns}"
          IO.puts "Body expression is: #{Macro.to_string expr}"
          gen_receive(patterns)
        any -> any
      end)
      IO.puts "New body is: #{Macro.to_string(instr_expr)}"
      IO.puts "New body is: #{inspect instr_expr, pretty: true}"
      instr_expr
    end

    # Helper function for waiting till the scheduler sends a `:go` message
    def receiving(receiver_fun) do
      sched = scheduler()
      receiver_fun.(fn ->
        Kernel.send(sched, {:block, self()})
        receive do
          {^sched, :go} -> receiving(receiver_fun)
        end
      end)
    end

    def gen_receive(receive_patterns) do
      call_fail = quote do failed.() end
      after_ast = {:after, [{:->, [], [[0], call_fail] }] }
      receive_expr = {:receive, [], [receive_patterns ++ [after_ast]]}
      quote do
        PropCheck.Tracer.Instrument.receiving(fn failed ->
          unquote(receive_expr)
        end)
      end
    end

  end

  defmodule Scheduler do
    @moduledoc """
    The Scheduler for the tracer. Currently without any interesting functionality.
    """
    use GenServer

    def init(init_arg) do
      {:ok, init_arg}
    end

    def handle_info(m = {:send, _source, dest, msg}, state) do
      IO.puts "Scheduler sends: #{inspect m}"
      Kernel.send(dest, msg)
      {:noreply, state}
    end
    def handle_info({:block, pid}, state) do
      IO.puts "Scheduler blocks #{inspect pid}"
      IO.puts "Scheduler sends :go"
      Kernel.send(pid, {__MODULE__, :go})
      {:noreply, state}
    end
  end
end
