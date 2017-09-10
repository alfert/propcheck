defmodule PropCheck.Properties do

  @moduledoc """
  This module defined the `property/4` macro. It is automatically available
  by `using PropCheck`.
  """

  @doc """
  Defines a property as part of ExUnit test.

  The property macro takes at minimum a name and a `do`-block containing
  the code of the property to be tested. The property code is encapsulated
  as ean `ExUnit` test case of category `property`, which is released as
  part of Elixir 1.3 and allows a nice mix of regular unit test and property
  based testing. This is the reason for the third parameter taking an
  environment of variables defined in a test setup function.

  The second parameter sets options for Proper (see `PropCheck` ). The default
  is `:quiet` such that execution during ExUnit runs are silent, as normal
  unit tests are. You can change it e.g. to `:verbose` or setting the
  maximum size of the test data generated or what ever may be helpful. For
  seeing the result of wrapper functions `PropCheck.aggregate/2` etc, the
  verbose mode is required.
  """

  alias PropCheck.CounterStrike
  require Logger

  defmacro property(name, opts \\ [:quiet], var \\ quote(do: _), do: p_block) do
      block = quote do
        unquote(p_block)
      end
      var   = Macro.escape(var)
      block = Macro.escape(block, unquote: true)
      quote bind_quoted: [name: name, block: block, var: var, opts: opts] do
          ExUnit.plural_rule("property", "properties")
          prop_name = ExUnit.Case.register_test(__ENV__, :property, name, [])
          %{module: module} = __ENV__
          # mfa = {module, prop_name, []}
          def unquote(prop_name)(unquote(var)) do
            p = unquote(block)
            mfa = {unquote(module), unquote(prop_name), []}
            execute_property(p, mfa, unquote(opts))
          end
      end
  end

  def execute_property(p, name, opts) do
    should_fail = is_tuple(p) and elem(p, 0) == :fails
    Logger.debug "Execute property #{inspect name} "
    case CounterStrike.counter_example(name) do
      :none -> property_body(p, name, opts)
      :others -> true # ignore the current property
      {:ok, counter_example} ->
        Logger.debug "Found for counter example #{inspect counter_example}"
        PropCheck.check(p, counter_example, [:long_result] ++opts)
    end
    |> handle_check_results(name, should_fail)
  end

  # this this the body of a property execution under ExUnit
  def handle_check_results(results, name, should_fail) do
    case results do
      true when not should_fail -> true
      true when should_fail ->
        raise ExUnit.AssertionError, [
          message:
            "#Property {unquote(name)} should fail, but succeeded for all test data :-(",
          expr: nil]
      _counter_example when should_fail -> true
      counter_example ->
        CounterStrike.add_counter_example(name, counter_example)
        raise ExUnit.AssertionError, [
          message: """
          Property #{mfa_to_string name} failed. Counter-Example is:
          #{inspect counter_example, pretty: true}
          """,
              expr: nil]
    end

  end

  # this this the body of a property execution under ExUnit
  def property_body(p, name, opts) do
    should_fail = is_tuple(p) and elem(p, 0) == :fails
    case PropCheck.quickcheck(p, [:long_result] ++opts) do
      true when not should_fail -> true
      true when should_fail ->
        raise ExUnit.AssertionError, [
          message:
            "#Property {mfa_to_string unquote(name)} should fail, but succeeded for all test data :-(",
          expr: nil]
      _counter_example when should_fail -> true
      counter_example ->
        CounterStrike.add_counter_example(name, counter_example)
        raise ExUnit.AssertionError, [
          message: """
          Property #{mfa_to_string name} failed. Counter-Example is:
          #{inspect counter_example, pretty: true}
          """,
              expr: nil]
    end
  end

  def mfa_to_string({m, f, []}) do
    "#{m}.#{f}()"
  end

  #####################
  # TODO:
  # * Create an ETS store for counterexamples, keyed by property name
  # * Store / Load the counterexamples during start/stop via :ets.tab2file
  # * property checks for a counterexample and runs it instead of the property
  # * extract property and counterexample handling from the macro for better testing
  # * provide a switch for mix to only run the counterexamples (true by default)
  # * provide a switch for mix where to store the counterexamples
  #
  #####################



  @doc false
  def print_mod_as_erlang(mod) when is_atom(mod) do
      {_m, beam, _file} = :code.get_object_code(mod)
      {:ok, {_, [{:abstract_code, {_, ac}}]}} = :beam_lib.chunks(beam, [:abstract_code])
      ac |> Enum.map(&:erl_pp.form/1) |> List.flatten |> IO.puts
  end

end
