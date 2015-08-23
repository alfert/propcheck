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
			# we need the Proper Definitions
			use PropCheck.Properties
			# use the original module
			import unquote(__MODULE__)
			# infer the defined types just before compilation (= code generation)
			# and inject for each type the corresponding generator function
			@before_compile unquote(__MODULE__)
		end
	end

	defmacro __before_compile__(env) do
		#IO.inspect env
		types = env.module 
			|> PropCheck.TypeGen.defined_types
			|> List.flatten
		types
			|> Enum.each &PropCheck.TypeGen.print_types/1
		(types |> Enum.map &convert_type/1)
		++
		(types |> Enum.map &generate_type_debug_fun/1)
		++
		[(types |> generate_all_types_debug_fun)]
	end

	@doc """
	Retrieves all types defined in the module `mod` which can be already a beam
	file or is an open module, i.e. it is currently worked on in the Elixir compiler.
	"""
	def defined_types(mod) do
		if Module.open? mod do
			IO.puts "Module #{mod} is open"
			[:type, :opaque, :typep] 
				|> Enum.map &(Module.get_attribute(mod,&1)) 
		else
			IO.puts "Module #{mod} is closed"
			[beam: Kernel.Typespec.beam_types(mod), attr: mod.__info__(:attributes)]
			Kernel.Typespec.beam_types(mod)
		end
	end
	
	def print_types({kind, {:::, _, [lhs, rhs]=t }, nil, _env}) when kind in [:type, :opaque, :typep] do
		IO.puts "Type definition for #{inspect lhs} ::= #{inspect rhs}"
	end

	@doc "Generates a `type_debug body(name, args)` containing the type definition before compilation. "
	def generate_type_debug_fun({kind, {:::, _, [{name, _, args}, _rhs]} = t, nil, _env} = typedef) do
		a = if args == nil, do: 0, else: length(args)
		t = Macro.escape(typedef)
		quote do
			def __type_debug__(unquote(name), unquote(a)) do
				# {unquote(kind), unquote(t)}
				unquote(t)
			end
		end
	end

	def generate_all_types_debug_fun(types) do
		ts = Macro.escape(types)
		quote do
			def __type_debug__(), do: unquote(ts) 
		end
	end
	

	@doc "Generates a function for a type definition"
	def convert_type({:typep, {:::, _, typedef}, nil, _env}) do
		header = type_header(typedef)
		body = type_body(typedef)
		quote do
			defp unquote(header) do
				unquote(body)
			end
		end
	end
	def convert_type({kind, {:::, _, typedef}, nil, _env}) when kind in [:type, :opaque] do
		header = type_header(typedef)
		body = type_body(typedef)
		quote do
			def unquote(header) do
				unquote(body)
			end
		end
	end
	
	@doc "Generates the type generator signature"
	def type_header([{name, _, nil}, _rhs]) do 
		quote do 
			unquote(name)()
		end
	end
	def type_header([{name, _, vars} = head, _rhs]) when is_atom(name) do
		head
	end
	
	@doc "Generates a simple body for the type generator function"
	# TODO: build up an environment of parameters to stop the recursion, if they are used
	#       otherwise a nested recursion like safe_stack does not work properly.
	def type_body([_lhs, rhs]), do: type_body(rhs)
	def type_body({:port, _, _}), do: throw "unsupported type port"
	def type_body({:pid, _, _}), do: throw "unsupported type pid"
	def type_body({:reference, _, _}), do: throw "unsupported type reference"
	def type_body({:atom, _, _}) do quote do atom end end
	def type_body({:any, _, _}) do quote do any end end
	def type_body({:float, _, _}) do quote do float(:inf, :inf) end end
	def type_body({:integer, _, _}) do quote do integer(:inf, :inf) end end
	def type_body({:non_neg_integer, _, _}) do quote do integer(0, :inf) end end
	def type_body({:pos_integer, _, _}) do quote do integer(1, :inf) end end
	def type_body({:neg_integer, _, _}) do quote do integer(:inf, -1) end end
	def type_body({:.., _, [left, right]}) do quote do integer(unquote(left), unquote(right)) end end
	def type_body({:{}, _, tuple_vars}) do quote do tuple(unquote(tuple_vars)) end end
	def type_body({:list, _, nil}) do quote do list(any) end end
	def type_body({:list, _, [type]}) do 
		param = type_body type
		quote do 
			:proper_types.list(unquote param) 
		end 
	end
	def type_body([type]) do 
		quote do 
			:proper_types.list(unquote(type_body(type))) 
		end 
	end
	# this doesn't work ==> go for proper recursive types, including :{}, :|, :list, :map
	#
	# this tuple detection also detects type variables and all not yet implemented type generators
	# therefore we need to detect these other situations properly, otherwise recursive definitions
	# do not work. 
	# IDEA: separate function for parameterized types types, such that access to type variables
	# properly identified (pair(f,s) is encoded as :{}, where my_int_tuple is a {..}!)
	def type_body(ts) when is_tuple(ts) do 
		IO.puts "found a tuple type: #{inspect ts}"
		types = ts |> :erlang.tuple_to_list 
			|> Enum.map &(type_body &1)
		quote do tuple(unquote(types)) end 
	end
	def type_body(body) do 
		body_s = "#{inspect body}"
		quote do 
			throw "catch all: no generator available for " <> unquote(body_s) 
		end 
	end



end