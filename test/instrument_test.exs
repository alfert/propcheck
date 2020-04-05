defmodule PropCheck.Test.InstrumentTester do
  @moduledoc """
  Tests the instrumentation functionalities
  """

  use ExUnit.Case
  import ExUnit.CaptureLog
  alias PropCheck.Instrument

  defmodule Identity do
    @moduledoc """
    Implements the Instrumentation as the identity function
    """
    require Logger
    @behaviour Instrument
    @impl true
    def handle_function_call(call) do
      Logger.error("handle_function: #{inspect call}")
      call
    end
  end

  test "Read the forms of the beam" do
    assert {:ok, forms} = Instrument.get_forms_of_module(PropCheck.Support.InstrumentExample)
    IO.inspect(forms, [pretty: true, limit: :infinity])
    assert tuple_size(forms) == 2
    {:abstract_code, code} = forms
    assert tuple_size(code) == 2
    assert {:raw_abstract_v1, clauses} = code
  end

  test "Initial instrumentation is the identity" do
    {:ok, forms} = Instrument.get_forms_of_module(PropCheck.Support.InstrumentExample)
    logs = capture_log fn ->
      instrumented_forms = Instrument.instrument_form(Identity, forms)
      assert forms == instrumented_forms
    end
    assert logs =~ "handle_function:"
  end

  test "instrumentable functions" do
    assert true == Instrument.instrumentable_function({:atom, 0, :gen_server}, {:atom, 0, :start_link})
  end
end
