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

    The second parameter sets options for Proper (see `PropCheck`). The default
    is `:quit` such that execution during ExUnit runs are silent, as normal
    unit tests are. You can change it e.g. to `:verbose` or setting the
    maximum size of the test data generated or what ever may be helpful. For
    seeing the result of wrapper functions `PropCheck.aggregate/2` etc, the
    verbose mode is required.
    """
    defmacro property(name, opts \\ [:quiet], var \\ quote(do: _), do: p_block) do
        block = quote do
          unquote(p_block)
        end
        var   = Macro.escape(var)
        block = Macro.escape(block, unquote: true)
        quote bind_quoted: [name: name, block: block, var: var, opts: opts] do
            ExUnit.plural_rule("property", "properties")
            prop_name = ExUnit.Case.register_test(__ENV__, :property, name, [])
            def unquote(prop_name)(unquote(var)) do
              p = unquote(block)
              should_fail = is_tuple(p) and elem(p, 0) == :fails
              case PropCheck.quickcheck(p, [:long_result] ++ unquote(opts)) do
                true when not should_fail -> true
                true when should_fail ->
                  raise ExUnit.AssertionError, [
                    message:
                      "#Property {unquote(name)} should fail, but succeeded for all test data :-(",
                    expr: nil]
                _counter_example when should_fail -> true
                counter_example ->
                  raise ExUnit.AssertionError, [
                    message: """
                    Property #{unquote(name)} failed. Counter-Example is:
                    #{inspect counter_example, pretty: true}
                    """,
                        expr: nil]
              end
            end
        end
    end
    @doc false
    @doc """
    Defines a property.

    The property is tested by calling the quickcheck function
    or (more usually) the `PropCheck.prop_test/1` macro which generates for
    each property in a file the corresponding `ExUnit` test cases.
    """
    defmacro old_property(name, opts) do
        prop_name = case name do
            {name, _, _} -> :"prop_#{name}"
            name when is_atom(name) or is_binary(name) or is_list(name) -> :"prop_#{name}"
        end
        quote do
            def unquote(prop_name)(), unquote(opts)
        end
    end

    @doc false
    def print_mod_as_erlang(mod) when is_atom(mod) do
        {_m, beam, _file} = :code.get_object_code(mod)
        {:ok, {_, [{:abstract_code, {_, ac}}]}} = :beam_lib.chunks(beam, [:abstract_code])
        ac |> Enum.map(&:erl_pp.form/1) |> List.flatten |> IO.puts
    end

end
