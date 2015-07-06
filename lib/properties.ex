defmodule PropCheck.Properties do
    defmacro __using__(_) do
        quote do
            import PropCheck
            import PropCheck.Properties
            import :proper_types, except: [lazy: 1, to_binary: 1, function: 2]
        end
    end
    
    defmacro property(name, opts) do
        case name do
            {name, _, _} ->
                prop_name = :"prop_#{name}"
            name when is_atom(name) or is_binary(name) or is_list(name) ->
                prop_name = :"prop_#{name}"
        end
        quote do
            def unquote(prop_name)(), unquote(opts)
        end
    end
end