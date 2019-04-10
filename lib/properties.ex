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
  seeing the result of wrapper functions `PropCheck.aggregate/2` etc., the
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

  After a property was ran successfully against a previous counter example, PropCheck will
  run the property again to check if other counter examples can be found.

  ### Disable Storing Counter Examples

  Storing counter examples can be disabled using the `:store_counter_example` tag. This
  can be done in three different scopes: module-wide scope, describe-wide scope or for
  a single property.

  **NOTE** that this facility is meant for properties which cannot run with a value generated
  in a previous test run. This should usually not be the case, and `:store_counter_example`
  should only be used after careful consideration.

  Disable for all properties in a module:

  ```
  defmodule Test do
    # ...
    @moduletag store_counter_example: false
    #...
  end
  ```

  Disable for all properties in a describe block:

  ```
  defmodule Test do
    # ...
    describe "describe block" do
      @describetag store_counter_example: false
      # ...
    end
  end
  ```

  Disable for a single property:

  ```
  @tag store_counter_example: false
  property "a property" do
    # ...
  end
  ```

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

          moduletag = Module.get_attribute(module, :moduletag) |> List.flatten()
          describetag = Module.get_attribute(module, :describetag) |> List.flatten()
          tag = Module.get_attribute(module, :tag) |> List.flatten()

          # intended precedence: tag > describetag > moduletag
          store_counter_example =
            moduletag
            |> Keyword.merge(describetag)
            |> Keyword.merge(tag)
            |> Keyword.get(:store_counter_example, true)

          # @tag failing_prop: tag_property({module, prop_name, []})
          tags = [[failing_prop: tag_property({module, name, []})]]
          prop_name = ExUnit.Case.register_test(__ENV__, :property, name, tags)
          def unquote(prop_name)(unquote(var)) do
            p = unquote(block)
            mfa = {unquote(module), unquote(prop_name), []}
            execute_property(p, mfa, unquote(opts), unquote(store_counter_example))
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
  def execute_property(p, name, opts, store_counter_example?) do
    should_fail = is_tuple(p) and elem(p, 0) == :fails
    # Logger.debug "Execute property #{inspect name} "
    case CounterStrike.counter_example(name) do
      :none -> PropCheck.quickcheck(p, [:long_result] ++ opts)
      :others ->
        # since the tag is set, we execute everything. You can limit
        # the amount of checks by using either --stale or --only failing_prop
        qc(p, opts)
      {:ok, counter_example} ->
        # Logger.debug "Found counter example #{inspect counter_example}"
        result = PropCheck.check(p, counter_example, [:long_result] ++ opts)
        with true <- result do
          qc(p, opts)
        else
          false -> {:rerun_failed, counter_example}
          e = {:error, _} -> e
        end
    end
    |> handle_check_results(name, should_fail, store_counter_example?)
  end

  defp qc(p, opts), do: PropCheck.quickcheck(p, [:long_result] ++ opts)

  # Handles the result of executing quick check or a re-check of a counter example.
  # In this method a new found counter example is added to `CounterStrike`.
  defp handle_check_results(results, name, should_fail, store_counter_example?) do
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
        counter_example_message =
          if store_counter_example? do
            CounterStrike.add_counter_example(name, counter_example)
            "Counter example stored."
          else
            "Counter example NOT stored, :store_counter_example is set."
          end

        raise ExUnit.AssertionError, [
          message: """
          Property #{mfa_to_string name} failed. Counter-Example is:
          #{inspect counter_example, pretty: true}

          #{counter_example_message}
          """,
          expr: nil]
      {:rerun_failed, counter_example} when is_list(counter_example) ->
        CounterStrike.add_counter_example(name, counter_example)
        raise ExUnit.AssertionError, [
          message: """
          Property #{mfa_to_string name} failed. Counter-Example is:
          #{inspect counter_example, pretty: true}

          Consider running `MIX_ENV=test mix propcheck.clean` if a bug in a generator was
          identified and fixed. PropCheck cannot identify changes to generators. See
          https://github.com/alfert/propcheck/issues/30 for more details.
          """,
          expr: nil]
    end
  end

  defp mfa_to_string({m, f, _}) do
    "#{m}.#{f}()"
  end

  @doc false
  def print_mod_as_erlang(mod) when is_atom(mod) do
      {_m, beam, _file} = :code.get_object_code(mod)
      {:ok, {_, [{:abstract_code, {_, ac}}]}} = :beam_lib.chunks(beam, [:abstract_code])
      ac |> Enum.map(&:erl_pp.form/1) |> List.flatten |> IO.puts
  end
end
