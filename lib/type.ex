defmodule PropCheck.Type do
	@moduledoc """
	This modules defines the syntax tree of types and translates the type definitions
	of Elixir into the internal format. It also provides functions for analysis of types. 
	"""

	@type env :: %{mfa: __MODULE__.t}
	@type kind_t :: :type | :opaque | :typep | :none

	defstruct name: :none,
		params: [],
		kind: :none,
		expr: nil,
		uses: []

	@type t :: %__MODULE__{name: atom, params: [atom], kind: kind_t, 
		expr: Macro.t, uses: [atom | mfa]}


	@doc "Takes a type specification as an Elixir AST and returns the type def."
	@spec parse_type({kind_t, Macro.t, nil, any}) :: t
	def parse_type({kind, {:::, _, [header, body] = typedef}, nil, _env}) 
	when kind in [:type, :opaque, :typep] do
		{name, _, ps} = header
		params = case ps do
			nil -> []
			l -> l |> Enum.map fn({n, _, _}) -> n end
		end
		%__MODULE__{name: name, params: params, kind: kind, expr: body}
	end
	
	@doc "Calculates the list of referenced types"
	def referenced_types({type_gen, _, l}, params) 
	when is_list(l) and type_gen in [:.., :{}, :list] do 
		l |> Enum.map(&(referenced_types(&1, params))) |> List.flatten
	end
	def referenced_types({:list, _, nil}, params) do [] end
	def referenced_types(body, params) do
		[]
	end
	

end