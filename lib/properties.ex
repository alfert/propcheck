defmodule PropCheck.Properties do

  @moduledoc """
  This module defined the `property/4` macro. It is automatically available
  by `use PropCheck`.
  """
  alias PropCheck.CounterStrike
  require Logger


  @doc """
  Defines a property as part of an ExUnit test.

  The property macro takes at minimum a name and a `do`-block containing
  the code of the property to be tested. The property code is encapsulated
  as an `ExUnit` test case of category `property`, which is released as
  part of Elixir 1.3 and allows a nice mix of regular unit test and property
  based testing. This is the reason for the third parameter taking an
  environment of variables defined in a test setup function. In `ExUnit`, this
  is referred to as a test's "context".

  The second parameter sets options for Proper (see `PropCheck` ). The default
  is `:quiet` such that execution during ExUnit runs are silent, as normal
  unit tests are. You can change it e.g. to `:verbose` or setting the
  maximum size of the test data generated or what ever may be helpful. For
  seeing the result of wrapper functions `PropCheck.aggregate/2` etc, the
  verbose mode is required.

  ## Counter Examples
  If a property fails, the counter example is in a file. The next time this
  property is checked again, only the counter example is used to ensure that
  the property now behaves correctly. Additionally, a property with an existing
  counter example is embellished with the tag `failing_prop`. You can skip all
  other tests and property by running `mix test --only failing_prop`. In this case
  only the properties with counter example are run. Another option is to use
  the `--stale` option of `ExUnit` to reduce the amount of tests and properties
  while fixing the code tested by a property.

  """
  defmacro property(name, opts \\ [:quiet], var \\ quote(do: _), do: p_block) do
      block = quote do
        unquote(p_block)
      end
      var   = Macro.escape(var)
      block = Macro.escape(block, unquote: true)
      quote bind_quoted: [name: name, block: block, var: var, opts: opts] do
          ExUnit.plural_rule("property", "properties")
          %{module: module} = __ENV__
          # @tag failing_prop: tag_property({module, prop_name, []})
          tags = [[failing_prop: tag_property({module, name, []})]]
          prop_name = ExUnit.Case.register_test(__ENV__, :property, name, tags)
          def unquote(prop_name)(unquote(var)) do
            p = unquote(block)
            mfa = {unquote(module), unquote(prop_name), []}
            execute_property(p, mfa, unquote(opts))
            :ok
          end
      end
  end

  @doc false
  # Returns the `failing_prop` tag value for the property. The `property_`
  # prefix is added to the function name. The value is determined by
  # looking up the `counter_example` in `CounterStrike` for the property.
  @spec tag_property(mfa) :: boolean
  def tag_property({m, f, a}) do
    mfa = {m, String.to_atom("property_#{f}"), a}
    case CounterStrike.counter_example(mfa) do
      {:ok, _} ->
        # Logger.debug "Found failing property #{inspect mfa}"
        true
      _ -> false
    end
  end

  @doc false
  # Executes the body `p` of property `name` with PropEr options `opts`
  # by ExUnit.
  def execute_property(p, name, opts) do
    should_fail = is_tuple(p) and elem(p, 0) == :fails
    # Logger.debug "Execute property #{inspect name} "
    case CounterStrike.counter_example(name) do
      :none -> PropCheck.quickcheck(p, [:long_result] ++opts)
      :others ->
        # since the tag is set, we execute everything. You can limit
        # the amount of checks by using either --stale or --only failing_prop
        PropCheck.quickcheck(p, [:long_result] ++opts)
      {:ok, counter_example} ->
        # Logger.debug "Found counter example #{inspect counter_example}"
        result = PropCheck.check(p, counter_example, [:long_result] ++opts)
        if result == false, do: counter_example, else: result
    end
    |> handle_check_results(name, should_fail)
  end

  # Handles the result of executing quick check or a re-check of a counter example.
  # In this method a new found counter example is added to `CounterStrike`.
  defp handle_check_results(results, name, should_fail) do
    case results do
      error = {:error, _} ->
        raise ExUnit.AssertionError, [
          message:
            "Property #{mfa_to_string name} failed with an error: #{inspect(error)}",
          expr: nil
        ]
      true when not should_fail -> true
      true when should_fail ->
        raise ExUnit.AssertionError, [
          message:
            "Property #{mfa_to_string name} should fail, but succeeded for all test data :-(",
          expr: nil]
      counter_example when is_list(counter_example) and should_fail -> true
      counter_example when is_list(counter_example) ->
        CounterStrike.add_counter_example(name, counter_example)
        raise ExUnit.AssertionError, [
          message: """
          Property #{mfa_to_string name} failed. Counter-Example is:
          #{inspect counter_example, pretty: true}
          """,
              expr: nil]
    end
  end

  defp mfa_to_string({m, f, []}) do
    "#{m}.#{f}()"
  end

  @doc false
  def print_mod_as_erlang(mod) when is_atom(mod) do
      {_m, beam, _file} = :code.get_object_code(mod)
      {:ok, {_, [{:abstract_code, {_, ac}}]}} = :beam_lib.chunks(beam, [:abstract_code])
      ac |> Enum.map(&:erl_pp.form/1) |> List.flatten |> IO.puts
  end
end
