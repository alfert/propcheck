defmodule PropCheck.YieldInstrumenter do
  @moduledoc """
  Instruments with prepending `:erlang.yield/0` for calls typical concurrency bug
  aware functions.
  """
  require Logger

  alias PropCheck.Instrument
  @behaviour Instrument
  @impl true
  def handle_function_call(call) do
    _ignore = Logger.debug("handle_function: #{inspect(call)}")
    Instrument.prepend_call(call, Instrument.call_yield())
  end

  @impl true
  def is_instrumentable_function(mod, fun), do: Instrument.instrumentable_function(mod, fun)
end
