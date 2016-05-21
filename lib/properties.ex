defmodule PropCheck.Properties do
    defmacro __using__(_) do
        quote do
            import PropCheck
            import PropCheck.Properties
            import :proper_types, except: [lazy: 1, to_binary: 1, function: 2]
        end
    end

    defmacro property(name, opts) do
        prop_name = case name do
            {name, _, _} -> :"prop_#{name}"
            name when is_atom(name) or is_binary(name) or is_list(name) -> :"prop_#{name}"
        end
        quote do
            def unquote(prop_name)(), unquote(opts)
        end
    end

    def print_mod_as_erlang(mod) when is_atom(mod) do
        {_m, beam, _file} = :code.get_object_code(mod)
        {:ok, {_, [{:abstract_code, {_, ac}}]}} = :beam_lib.chunks(beam, [:abstract_code])
        ac |> Enum.map(&:erl_pp.form/1) |> List.flatten |> IO.puts
    end

end
