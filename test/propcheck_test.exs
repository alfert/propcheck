defmodule PropcheckTest do
	use ExUnit.Case
	require Logger

	@moduletag capture_log: true

	@type my_stack(t) :: [t]
	@type tagged_stack(t) :: {:stack, [t]}


	test "find types in proper_gen.erl" do
		types = Kernel.Typespec.beam_types(:proper_gen)
		refute nil == types

		Logger.debug(inspect types, pretty: true)
	end

  def recode_vars({:var, line, n}), do:
		{:var, line, n |> Atom.to_string |> String.upcase |> String.to_atom}
  def recode_vars({t, l, sub_t, expr}), do: {t, l, recode_vars(sub_t), recode_vars(expr)}
  def recode_vars([]), do: []
  def recode_vars([h | t]), do: [recode_vars(h) | recode_vars(t)]
  def recode_vars(what_ever), do: what_ever

	def get_type_in_abstract_form(module, type_name, arg_count \\ 0) do
	    case abstract_code(module) do
    		{:ok, abstract_code} ->
        		# exported_types = for {:attribute, _, :export_type, types} <- abstract_code, do: types
        		# exported_types = :lists.flatten(exported_types)

          for {:attribute, _, kind, {name, _, args}} = type <- abstract_code, kind
 					  in [:opaque, :type, :export_type] do
              if (name == type_name and arg_count == length(args)) do
                type
              else
                nil
              end
          end
    	end
	end

	# Taken from Kernel.TypeSpec
	defp abstract_code(module) do
    	case :beam_lib.chunks(abstract_code_beam(module), [:abstract_code]) do
      		{:ok, {_, [{:abstract_code, {_raw_abstract_v1, abstract_code}}]}} ->
        		{:ok, abstract_code}
      		_ ->
        		:error
    	end
  	end

  	defp abstract_code_beam(module) when is_atom(module) do
    	case :code.get_object_code(module) do
      		{^module, beam, _filename} -> beam
      		:error -> module
    	end
  	end

  	defp abstract_code_beam(binary) when is_binary(binary) do
    	binary
  	end


end
