defmodule PropCheck.Type do
	@moduledoc """
	This modules defines the syntax tree of types and translates the type definitions
	of Elixir into the internal format. It also provides functions for analysis of types.
	"""

	@type env :: %{mfa: __MODULE__.t}
	@type kind_t :: :type | :opaque | :typep | :none

	@predefined_types [:atom, :integer, :pos_integer, :neg_integer, :non_neg_integer, :boolean, :byte,
		:char, :number, :char_list, :any, :term, :io_list, :io_data, :module, :mfa, :arity, :port,
		:node, :timeout, :fun, :binary, :bitstring]
	@unsupported_types [:port, :node, :reference, :module, :mfa]

	defstruct name: :none,
		params: [],
		mod: :none,
		kind: :none,
		expr: nil,
		uses: []

	@type t :: %__MODULE__{name: atom, params: [atom], mod: atom, kind: kind_t,
		expr: TypeExpr.t, uses: [atom | mfa]}

	defmodule TypeExpr do
		@typedoc """
		Various type constructors, `:ref` denote a reference to an existing type or
		parameter, `:literal` means a literal value, in many cases, this will be an atom value.

		Nonempty lists are encoded like a list, but have a second type parameter, which is the
		literal `:...`.
		"""
		@type constructor_t :: :union | :tuple | :list | :map | :ref | :range | :fun |
			:literal | :var | :none
		defstruct constructor: :none,
			args: [] # elements of union, tuple, list or map; or the referenced type or the literal value

		@type t :: %__MODULE__{constructor: constructor_t, args: [Macro.t | t]}
		def preorder(%__MODULE__{args: []} = t), do: [t]
		def preorder(%__MODULE__{args: a} = t) when not is_list(a), do: [t]
		def preorder(%__MODULE__{args: a} = t), do:
			[t | (a |> Enum.map fn ta -> preorder(ta) end) |> List.flatten]
		# this looks strange, but this is an arg value which is not a type expr.
		# this is ignored in the pre-order, its value is contained in the type expr above.
		def preorder(_value), do: []

		defimpl Inspect, for: __MODULE__ do
			import Inspect.Algebra

			def inspect(%{constructor: c, args: a}, opts) do
				surround_many("%#{TypeExpr}{",
					[constructor: c, args: a],
					"}",
					%Inspect.Opts{limit: :infinity},
					fn {f, v}, _o -> group glue(concat(Atom.to_string(f), ":"), to_doc(v, opts)) end
				)
			end
		end
	end

	@doc """
	Creates an environment of named types for a module. Expects as input the list of types
	of a module.
	"""
	@spec create_environment([Macro.t], atom) :: env
	def create_environment(types, mod) do
		types
			|> Stream.map(&parse_type/1)
			|> Stream.map(fn %__MODULE__{name: n, params: p} = t -> {{mod, n, length(p)}, t} end)
			|> Enum.into %{}
	end



	@doc "Takes a type specification as an Elixir AST and returns the type def."
	@spec parse_type({kind_t, Macro.t, nil, any}) :: t
	def parse_type({kind, {:::, _, [header, body] = _typedef}, nil, _env})
	when kind in [:type, :opaque, :typep] do
		{name, _, ps} = header
		params = case ps do
			nil -> []
			l -> l |> Enum.map fn({n, _, _}) -> n end
		end
		# IO.puts "Type body is: #{inspect body}"
		%__MODULE__{name: name, params: params, kind: kind, expr: parse_body(body, params)}
	end

	@doc "Parse the body of a type spec as an Elixir AST and returns the `TypeExp`"
	@spec parse_body(Macro.t, [atom]) :: t
	def parse_body({:|, _, children}, params) do
		args = children |> Enum.map fn child -> parse_body(child, params) end
		%TypeExpr{constructor: :union, args: args}
	end
	def parse_body({:{}, _, children}, params) do
		args = children |> Enum.map fn child -> parse_body(child, params) end
		%TypeExpr{constructor: :tuple, args: args}
	end
	def parse_body({:%{}, _, children}, params) do
		args = children |> Enum.map fn child -> parse_body(child, params) end
		%TypeExpr{constructor: :map, args: args}
	end
	def parse_body({:.., _, children}, params) do
		args = children |> Enum.map fn child -> parse_body(child, params) end
		%TypeExpr{constructor: :range, args: args}
	end
	# strange syntax tree: a ĺist containing the function type
	def parse_body([{:->, _, children}], params) do
		args = children |> Enum.map fn child -> parse_body(child, params) end
		%TypeExpr{constructor: :fun, args: args}
	end
	# "..." is any arity of a function or a non-empty list.
	def parse_body({:..., _, nil}, _params) do
		%TypeExpr{constructor: :literal, args: [:...]}
	end
	def parse_body({type, _, nil}, _params) when type in @predefined_types do
		%TypeExpr{constructor: :ref, args: [type]}
	end
	def parse_body({t, _, nil}, params) when is_atom(t) do
		case params |> Enum.member? t do
			true -> %TypeExpr{constructor: :var, args: [t]}
			_ -> %TypeExpr{constructor: :ref, args: [t]}
		end
	end
	# handle list(t) different because list is predefined type
	def parse_body({:list, _, [subtype]}, params) do
		p = parse_body subtype, params
		%TypeExpr{constructor: :list, args: [p]}
	end
	def parse_body({type, _, sub}, params) when is_atom(type) do
		ps = sub |> Enum.map fn s -> parse_body s, params end
		%TypeExpr{constructor: :ref, args: [type, ps]}
	end
	def parse_body(body, params) when is_tuple(body) do
		args = body
			|> Tuple.to_list
			|> Enum.map fn child -> parse_body(child, params) end
		%TypeExpr{constructor: :tuple, args: args}
	end
	def parse_body(body, params) when is_list(body) do
		args = body
			|> Enum.map fn child -> parse_body(child, params) end
		%TypeExpr{constructor: :list, args: args}
	end
	def parse_body(body, _params) when not(is_tuple(body)) do
		%TypeExpr{constructor: :literal, args: [body]}
	end


	@doc "Calculates the list of referenced types"
	def referenced_types({type_gen, _, l}, params)
	when is_list(l) and type_gen in [:.., :{}, :list] do
		l |> Enum.map(&(referenced_types(&1, params))) |> List.flatten
	end
	def referenced_types({:list, _, nil}, _params) do [] end
	def referenced_types(_body, _params) do
		[]
	end

	@doc "Analyzes if the type definition is recursive"
	@spec is_recursive(mfa, env ) :: boolean
	def is_recursive({_m, _f, _a} = t, env) do
		# ensure that t is defined in env, otherwise we cannot check anything
		{:ok, type} = env |> Dict.fetch(t)
		%__MODULE__{} = type
		is_recursive(t, type, env)
	end
	def is_recursive(mfa, %__MODULE__{expr: expr, params: ps}, env) do
		# add all parameters to the environment. We use a TypeExpr for it
		# but what is the true reason for this?
		new_env = ps
			|> Stream.map(fn p ->
				t = %TypeExpr{constructor: :var, args: [p]}
				{t, t}
			end)
			|> Enum.into(env)
		# 	|> IO.inspect
		# IO.puts "OK, new_env is there, now the expressions!"
		is_recursive(mfa, expr, new_env)
	end

	@doc "Analyzes of the type expression for `mfa` is recursive"
	@spec is_recursive(mfa, TypeExpr.t, env) :: boolean
	def is_recursive(_mfa, %TypeExpr{constructor: con}, _env) when
		con in [:literal, :range], do: false
	def is_recursive(_mfa, %TypeExpr{constructor: :var}, _env), do: false
	def is_recursive(_mfa, %TypeExpr{constructor: :ref, args: [type]}, _env)
		when type in @predefined_types, do: false
	def is_recursive(mfa, %TypeExpr{constructor: :ref, args: [type]}, env) do
		# type is not predefined ==> it must existent in env, so we can look deeper into it.
		case type do
			^mfa -> true
			_ -> # anything other must be present in the environment
				#
				# Hmm, what about types of other modules (=mfa) or parameterized types?
				{:ok, t} = env |> Dict.fetch(type)
				is_recursive(mfa, t, env)
		end
	end
	def is_recursive(mfa, %TypeExpr{constructor: con, args: args}, env)
			when con in  [:union, :tuple, :list, :map] do
		args |> Enum.any? fn t -> is_recursive(mfa, t, env) end
	end
	def is_recursive(mfa, %TypeExpr{constructor: :ref, args: [t | args]}, env) do
		case match_type(mfa, t) do
			true -> true
			_ -> args |> Enum.any? fn ta -> is_recursive(mfa, ta, env) end
		end
	end


	def match_type(mfa1, mfa2) when mfa1 == mfa2, do: true
	def match_type({_m, f1, _a}, f2) when f1 == f2, do: true
	def match_type(_, _), do: false


	@spec type_generators(env) :: Macro.t
	def type_generators(env) do
		env
			|> Enum.map(fn {mfa, type} -> type_generator(mfa, type) end)
	end

	def type_generator(mfa, %__MODULE__{expr: type, params: ps, kind: kind}) do
		header = header_for_type(mfa, ps)
		body = body_for_type(type)
		d = if (kind == :typep) do :defp else :def end
		{d, [context: Elixir, import: Kernel],
			[header, [do: body]]}
	end

	@doc "Generates the AST for a function head."
	def header_for_type({m, f, a}, ps) when length(ps) == a do
		{
			f, [context: m],
			if (ps == []) do nil
				else
				 ps |> Enum.map(fn p -> {p, [], m} end)
			end
		}
	end


	def body_for_type(%TypeExpr{constructor: :ref, args: [t]})
		when t in @unsupported_types, do: throw "unsupported type port"
	def body_for_type(%TypeExpr{constructor: :ref, args: [t]})
		when t in @predefined_types, do: body_for_predefined_type(t)
	def body_for_type(%TypeExpr{constructor: list, args: [p]}) do
		%TypeExpr{constructor: :var, args: [t]} = p
		quote do
			list(unquote(t))
		end
	end
	def body_for_type(%TypeExpr{constructor: _con, args: _args} = t) do
		t_msg = inspect t
		quote do
			throw "Unimplemented generator for type " <> unquote(t_msg)
		end
	end

	def body_for_predefined_type(:atom) do quote do atom end end
	def body_for_predefined_type(:any) do quote do any end end
	def body_for_predefined_type(:term) do quote do term end end
	def body_for_predefined_type(:float) do quote do float(:inf, :inf) end end
	def body_for_predefined_type(:integer) do quote do integer(:inf, :inf) end end
	def body_for_predefined_type(:non_neg_integer) do quote do integer(0, :inf) end end
	def body_for_predefined_type(:pos_integer) do quote do integer(1, :inf) end end
	def body_for_predefined_type(:neg_integer) do quote do integer(:inf, -1) end end
	def body_for_predefined_type(:byte) do quote do integer(0, 255) end end
	def body_for_predefined_type(:arity) do quote do integer(0, 255) end end
	def body_for_predefined_type(:boolean) do quote do boolean end end
	def body_for_predefined_type(:char) do quote do char end end
	def body_for_predefined_type(:number) do quote do number end end
	def body_for_predefined_type(:char_list) do quote do char_list end end
	def body_for_predefined_type(:io_list) do quote do io_list end end
	def body_for_predefined_type(:io_data) do quote do io_data end end
	def body_for_predefined_type(:timeout) do quote do timeout end end
	def body_for_predefined_type(:fun) do quote do fun end end
	def body_for_predefined_type(:binary) do quote do binary end end
	def body_for_predefined_type(:bitstring) do quote do bitstring end end

	def body_for_predefined_type({:.., _, [left, right]}) do quote do integer(unquote(left), unquote(right)) end end
	def body_for_predefined_type({:{}, _, tuple_vars}) do quote do tuple(unquote(tuple_vars)) end end
	def body_for_predefined_type({:list, _, nil}) do quote do list(any) end end
	def body_for_predefined_type({:list, _, [_type]}) do :ok end

end
