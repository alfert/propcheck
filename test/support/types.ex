defmodule PropCheck.Test.Types do
	@moduledoc """
	This module contains various type definitions to check that the generator generation
	works properly. 
	"""
	use PropCheck.TypeGen

	@type my_numbers :: integer
	@type my_small_numbers :: 0..100
	@type yesno :: :yes | :no

	@type my_list(t) :: [t]
	@type safe_stack(t) :: {pos_integer, list(t)}

	@opaque tree(t) :: :leaf | {:node, t, tree(t), tree(t)}

	@type pair(fst,snd) :: {:pair, fst, snd}
	@type my_int_tuple :: {integer, integer}

	@type my_map :: %{atom => integer, integer => boolean}

	defstruct name: :unknown, args: [] 
	@type my_struct :: %{name: atom, args: [atom]}

	@type any_fun :: (... -> any)
	@type side_effect :: (() -> any)
	@type call_back :: (atom, boolean -> [atom])
end