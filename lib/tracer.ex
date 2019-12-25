defmodule PropCheck.Tracer do
  @moduledoc """
  Provides the tracer subsystem of PropCheck, an independent implementation of
  the QuickChecks Pulse ideas.
  """

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
        import Kernel, except: [send: 2, spawn: 1] # , def: 2 ]
        defdelegate send(m, d), to: PropCheck.Tracer.Instrument
        defdelegate spawn(f), to: PropCheck.Tracer.Instrument
        defmacro def(call, expr) do
          IO.outs "Defining #{inspect call}"
          instr_expr = PropCheck.Tracer.Instrument.instrument(expr)
          quote do
            Kernel.def(call, instr_expr)
          end
        end
        # @before_compile unquote(__MODULE__)
      end
    end

    def __before_compile__(env) do
      IO.puts "before compile for #{inspect env}"
      #IO.puts "We are in module #{inspect env.module}"
    end

    def instrument(expr) do
      instr_expr = Macro.prewalk(expr, fn
        {:receive, _info, [patterns]} -> # identify do: patterns Und after: clause, diese müssen bei
          # gen_receive als Argument übernommen werden.
          IO.puts "instrument receive"
          gen_receive(patterns)
        any -> any
      end)
      instr_expr
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
      quote do
        PropCheck.Tracer.Instrument.receiving(fn failed ->
          receive do
            :patterns
          after 0 -> failed.()
          end
        end)
      end
      |> Macro.prewalk(fn
        [:patterns] -> receive_patterns
        any -> any
      end)
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
      Kernel.send(pid, {__MODULE__, :go})
      {:noreply, state}
    end
  end
end
