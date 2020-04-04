defmodule PropCheck.Test.InstrumentTester do
  @moduledoc """
  Tests the instrumentation functionalities
  """

  use ExUnit.Case

  alias PropCheck.Instrument

  test "Read the forms of the beam" do
    assert {:ok, forms} = Instrument.get_forms_of_module(PropCheck.Support.InstrumentExample)
    IO.inspect(forms, [pretty: true, limit: :infinity])
    assert tuple_size(forms) == 2
    {:abstract_code, code} = forms
    assert tuple_size(code) == 2
    {raw_abstract_v1, clauses} = code
  end

  test "Initial instrumentation is the identity" do
    {:ok, forms} = Instrument.get_forms_of_module(PropCheck.Support.InstrumentExample)
    instrumented_forms = Instrument.instrument_form(forms)
  end

end
