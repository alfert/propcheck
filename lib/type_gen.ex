defmodule PropCheck.TypeGen do
	@moduledoc """
	This module creates type generating functions from type specifications.

	This is Elixir version of PropEr's parse transformation
	"""

	@doc """
	This function lists the types defined in the module. If the module is open (i.e. it is 
	currently compiled) it shall work, but also after the compilation. The first one is required
	for adding type generator functions during compilation, the latter is used for inspecting
	and generating functions for types in a remote defined module (e.g. from the the Standard lib)
	"""

	defmacro __using__(_options) do
		quote do
			# use the original module
			import unquote(__MODULE__)
			# infer the defined types just before compilation (= code generation)
			# and inject for each type the corresponding generator function
			@before_compile unquote(__MODULE__)
		end
	end

	defmacro __before_compile__(env) do
		#IO.inspect env
		env.module 
			|> PropCheck.TypeGen.defined_types
			|> List.flatten
			|> Enum.each &PropCheck.TypeGen.print_types/1
		[]	
	end

	def defined_types(mod) do
		if Module.open? mod do
			IO.puts "Module #{mod} is open"
			[:type, :opaque, :typep] 
				|> Enum.map &(Module.get_attribute(mod,&1)) 
		else
			IO.puts "Module #{mod} is closed"
			[beam: Kernel.Typespec.beam_types(mod), attr: mod.__info__()]
		end
	end
	
	def print_types({kind, {:::, _, [lhs, rhs]}, nil, _env}) when kind in [:type, :opaque, :typep] do
		IO.puts "Type definition for #{inspect lhs} ::= #{inspect rhs}"
	end
	def print_types(types) when is_list(types) do
		IO.puts "Types: Got a list with #{length(types)} elements"
	end
	

end