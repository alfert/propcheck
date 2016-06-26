defmodule PropCheck.Properties do

  @moduledoc """
  This module defined the `property/2` macro. It is automatically available
  by `using PropCheck`.
  """

    defmacro __using__(_) do
        quote do
            import PropCheck
            import PropCheck.Properties
            import :proper_types, except: [lazy: 1, to_binary: 1, function: 2]
        end
    end

    @doc """
    Defines a property a part of ExUnit test.

    """
    defmacro property(name, var \\ quote(do: _), do: opts) do
        block = quote do
          unquote(opts)
        end
        var   = Macro.escape(var)
        block = Macro.escape(block, unquote: true)
        quote bind_quoted: [name: name, block: block, var: var] do
            ExUnit.plural_rule("property", "properties")
            prop_name = ExUnit.Case.register_test(__ENV__, :property, name, [])
            def unquote(prop_name)(unquote(var)) do
              p = unquote(block)
              should_fail = is_tuple(p) and elem(p, 0) == :fails
              case PropCheck.quickcheck(p, [:long_result, :quiet]) do
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
