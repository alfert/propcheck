defmodule PropCheck.Test.InstrumentTester do
  @moduledoc """
  Tests the instrumentation functionalities
  """

  use ExUnit.Case
  import ExUnit.CaptureLog
  import ExUnit.CaptureIO
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

  defmodule MessageInstrumenter do
    @moduledoc """
    Implements the Instrumentation as puts of `"Instrumented!" before calling the original function.
    """
    require Logger
    @behaviour Instrument
    @impl true
    def handle_function_call(call) do
      Logger.error("handle_function: #{inspect call}")
      puts_msg = Instrument.encode_call({__MODULE__, :log_hello, ["instrumented!"]})
      Instrument.prepend_call(call, puts_msg)
    end

    def log_hello(msg) do
      Logger.info(msg)
    end
  end

  test "Read the forms of the beam" do
    mod = PropCheck.Support.InstrumentExample
    assert {:ok, filename, forms} = Instrument.get_forms_of_module(mod)
    IO.inspect(forms, [pretty: true, limit: :infinity])
    assert tuple_size(forms) == 2
    {:abstract_code, code} = forms
    assert tuple_size(code) == 2
    assert {:raw_abstract_v1, clauses} = code

    expected_path = Path.join(["_build", "test", "lib", "propcheck", "ebin"])
    assert expected_path == Path.relative_to_cwd(filename) |> Path.dirname()
    assert Atom.to_string(mod) <> ".beam" == Path.basename(filename)
  end

  test "Initial instrumentation is the identity" do
    {:ok, _file, forms} = Instrument.get_forms_of_module(PropCheck.Support.InstrumentExample)
    logs = capture_log fn ->
      instrumented_forms = Instrument.instrument_form(Identity, forms)
      assert forms == instrumented_forms
    end
    assert logs =~ "handle_function:"
  end

  test "instrumentable functions" do
    assert true == Instrument.instrumentable_function({:atom, 0, :gen_server}, {:atom, 0, :start_link})
  end

  test "compile the retrieved forms" do
    mod = PropCheck.Support.InstrumentExampleSimple
    {:ok, filename, forms} = Instrument.get_forms_of_module(mod)
    compile_result = Instrument.compile_module(mod, filename, forms)

    assert {:ok, ^mod, _module, []} = compile_result
  end

  test "prepending a call" do
    mod = PropCheck.Support.InstrumentExampleSimple
    output = capture_io fn -> mod.hello() end
    assert output =~ "Hello"

    {:ok, filename, forms} = Instrument.get_forms_of_module(mod)
    altered_forms = Instrument.instrument_form(MessageInstrumenter, forms)

    assert altered_forms != forms

    compile_result = Instrument.compile_module(mod, filename, altered_forms)
    assert {:ok, ^mod, _module, []} = compile_result

    # This assertion might break if before this test another instrumentation happens
    mods = :code.modified_modules()
    assert [mod] == mods

    {:ok, ^mod, _module, []} = compile_result
    log_output = capture_log fn -> mod.hello() end
    assert log_output =~ "instrumented!"
    # assert log_output =~ "Hello"
  end

  test "instrument an entire module" # do
  #   mod = PropCheck.Support.InstrumentExample
  #   # Idea: 1 Validate that no yields are available [how? how to recurse over the structure]
  #   #       2 instrument the code
  #   #       3 check that yield is inside the module now
  # end
end
