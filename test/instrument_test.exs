defmodule PropCheck.Test.InstrumentTester do
  @moduledoc """
  Tests the instrumentation functionalities
  """

  use ExUnit.Case
  import ExUnit.CaptureLog
  import ExUnit.CaptureIO
  alias PropCheck.Instrument
  require Logger

  defmodule Identity do
    @moduledoc """
    Implements the Instrumentation as the identity function
    """
    require Logger
    @behaviour Instrument
    @impl true
    def handle_function_call(call) do
      Logger.debug("handle_function: #{inspect(call)}")
      call
    end

    @impl true
    def is_instrumentable_function(mod, fun), do: Instrument.instrumentable_function(mod, fun)
  end

  defmodule MessageInstrumenter do
    @moduledoc """
    Implements the Instrumentation as logging `"Instrumented!" before calling the original function.
    """
    require Logger
    @behaviour Instrument
    @impl true
    def handle_function_call(call) do
      Logger.debug("handle_function: #{inspect(call)}")
      puts_msg = Instrument.encode_call({__MODULE__, :log_hello, ["instrumented!"]})
      Instrument.prepend_call(call, puts_msg)
    end

    @impl true
    def is_instrumentable_function(mod, fun), do: Instrument.instrumentable_function(mod, fun)

    def log_hello(msg) do
      Logger.info(msg)
    end
  end

  test "Read the forms of the beam" do
    mod = PropCheck.Support.InstrumentExample
    assert {:ok, filename, forms} = Instrument.get_forms_of_module(mod)
    Logger.debug("#{inspect(forms, pretty: true, limit: :infinity)}")
    assert tuple_size(forms) == 2
    {:abstract_code, code} = forms
    assert tuple_size(code) == 2
    assert {:raw_abstract_v1, _clauses} = code

    expected_path = Path.join(["_build", "test", "lib", "propcheck", "ebin"])
    assert expected_path == Path.relative_to_cwd(filename) |> Path.dirname()
    assert Atom.to_string(mod) <> ".beam" == Path.basename(filename)
  end

  test "Initial instrumentation is the identity" do
    {:ok, _file, forms} = Instrument.get_forms_of_module(PropCheck.Support.InstrumentExample)

    logs =
      capture_log(fn ->
        instrumented_forms = Instrument.instrument_forms(Identity, forms)
        assert forms == instrumented_forms
      end)

    assert logs =~ "handle_function:"
  end

  test "instrumentable functions" do
    # Instrument.print_fun(:instrumentable_function)
    assert true ==
             Instrument.instrumentable_function({:atom, 0, :gen_server}, {:atom, 0, :start_link})

    assert true ==
             Instrument.instrumentable_function({:atom, 0, GenServer}, {:atom, 0, :start_link})

    assert true == Instrument.instrumentable_function({:atom, 0, IO}, {:atom, 0, :puts})
  end

  test "compile the retrieved forms" do
    mod = PropCheck.Support.InstrumentExampleSimple
    {:ok, filename, forms} = Instrument.get_forms_of_module(mod)
    compile_result = Instrument.compile_module(mod, filename, forms)

    assert {:ok, ^mod, _module, []} = compile_result
  end

  test "prepending a call" do
    mod = PropCheck.Support.InstrumentExampleSimple
    output = capture_io(fn -> mod.hello() end)
    assert output =~ "Hello"

    {:ok, filename, forms} = Instrument.get_forms_of_module(mod)
    altered_forms = Instrument.instrument_forms(MessageInstrumenter, forms)
    # There must change something, otherwise our instrumentation is wrong!
    assert altered_forms != forms

    compile_result = Instrument.compile_module(mod, filename, altered_forms)
    assert {:ok, ^mod, _module, []} = compile_result

    # This is robust even if we are running cover compiled, but we cannot check whether
    # we modified the cover compiled module instance
    # The check works only for OTP >= 20
    try do
      assert Enum.member?(:code.modified_modules(), mod)
    rescue
      UndefinedFunctionError ->
        Logger.info(
          ":code.modified_modules/0 available since OTP 20 but you have: " <>
            System.otp_release()
        )
    end

    {:ok, ^mod, _module, []} = compile_result
    log_output = capture_log(fn -> mod.hello() end)
    assert log_output =~ "instrumented!"
  end

  test "instrument an entire module" do
    mod = PropCheck.Support.InstrumentExample

    assert {:ok, ^mod, _module, []} = Instrument.instrument_module(mod, MessageInstrumenter)
    # This is robust even if we are running cover compiled, but we cannot check whether
    # we modified the cover compiled module instance
    # The check works only for OTP >= 20
    try do
      assert Enum.member?(:code.modified_modules(), mod)
    rescue
      UndefinedFunctionError ->
        Logger.info(
          ":code.modified_modules/0 available since OTP 20 but you have: " <>
            System.otp_release()
        )
    end

    assert Instrument.is_instrumented?(mod)

    {:ok, _filename, code} = Instrument.get_forms_of_module(mod)
    {:abstract_code, {:raw_abstract_v1, forms}} = code

    Enum.filter(forms, fn
      {:attribute, _, _, _} -> true
      _ -> false
    end)
    |> Enum.each(fn e -> Logger.debug("Attribute: #{inspect(e)}") end)

    # This assertion should hold, but does not, because the custom attribute is not stored.
    # assert Instrument.is_instrumented?(forms)  == {:attribute, 1, :instrumented, PropCheck}
    assert Instrument.is_instrumented?(forms) == false
    Logger.debug(inspect(mod.module_info(:attributes)))
  end

  @tag will_fail: true
  # Fails as asn1rt_nif is not available
  test "instrument an entire application" do
    Logger.debug("All Apps: #{inspect(Application.loaded_applications())}")
    # The asn1 compiler is not really used, so no damage is expected
    app = :asn1
    assert all_modules = Application.spec(app, :modules)
    Enum.each(all_modules, fn m -> assert not Instrument.is_instrumented?(m) end)

    assert :ok == Instrument.instrument_app(app, MessageInstrumenter)

    Enum.each(all_modules, fn m -> assert Instrument.is_instrumented?(m) end)
  end
end
