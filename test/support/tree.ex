defmodule PropCheck.Test.Tree do
	@moduledoc """
	The tree implementation of 2013 tutorial, Elixir version.
	"""

	use PropCheck.Properties

	@type tree(t) :: :leaf | {:node, t, tree(t), tree(t)}

	@spec member(tree(t), t) :: boolean when t: var
	def member(:leaf, _), do: false
	def member({:node, x, _, _}, x), do: true
	def member({:node, _, left, right}, x) do
		member(left, x) or member(right, x)
	end

	@spec join(tree(t), tree(t)) :: tree(t) when t: var
	def join(:leaf, t2), do: t2
	def join({:node, x, l1, r1}, t2) do
		{:node, x, join(l1, r1), t2}
	end

	@doc """
	Bad delete implementation: doesn't delete any occurence of X that is
	nested under some other node containing X
	"""
	@spec delete(tree(t), t) :: tree(t) when t: var
	def delete(:leaf, _), do: :leaf
	def delete({:node, x, l, r}, x), do: join(l, r)
	def delete({:node, y, l, r}, x), do: {:node, y, delete(l, x), delete(r, x)}

	@doc "Corrected delete implementation"
	@spec delete2(tree(t), t) :: tree(t) when t: var
	def delete2(:leaf, _), do: :leaf
	def delete2({:node, x, l, r}, x), do: join(delete2(l, x), delete2(r,x))
	def delete2({:node, y, l, r}, x), do: {:node, y, delete2(l, x), delete2(r, x)}

	@spec tree_sum(tree(number)) :: number
	def tree_sum(:leaf), do: 0
	def tree_sum({:node, x, l, r}), do: x + tree_sum(l) + tree_sum(r)

	@spec pre_order(tree(t)) :: [t] when t: var
	def pre_order(:leaf), do: []
	def pre_order({:node, x, l, r}), do: [x] ++ pre_order(l) ++ pre_order(r)

	################################
	### Properties of the tree

	# delete is faulty, therefore we expect it fail now and then
	property "delete" do
		forall {x, t} in {integer, tree(integer)} do
			not member(delete2(t, x), x)
		end
	end

	# Example of a PBT strategy: finding two distinct computations that should
	# result in the same value.
	property "sum" do
		forall t in tree(integer) do
			pre_order(t) |> Enum.sum == tree_sum(t)
		end
	end

	##################################
	## Custom Generators for trees
	def tree(g), do: tree6(g)

	@doc "Attempts at writing a generator for trees:"
	def tree1(g), do:
	    union([
	    	:leaf,
        	{:node, g, tree1(g), tree1(g)}
        ])

    @doc "Erlang is eager: we need to enforce lazy evaluation to avoid infinite recursion"
    def tree2(g), do:
    	union([
    		:leaf,
    		lazy {:node, g, tree2(g), tree2(g)}
    	])

    @doc """
    Generation might not terminate: we need to introduce a bound on the number
    of recursive calls (and thus the size of the produced term), by handling the
    `size` parameter manually.

    The base case is delegated to the 0-size clause.
    All non-recursive cases are replaced by fallbacks to that clause.
    """
    def tree3(g), do: sized(s, tree3(s, g))
    def tree3(0, _), do: :leaf
    def tree3(s, g), do:
    	union([
    		tree3(0, g),
    		lazy {:node, g, tree3(s, g), tree3(s, g)}
    	])

    @doc """
    50% of the time, the tree is empty: we should set the weights in the union
    to ensure a satisfactory average size of produced instances.
    """
    def tree4(g), do: sized(s, tree4(s, g))
    def tree4(0, _), do: :leaf
    def tree4(s, g), do:
    	frequency [
    		{1, tree4(0, g)},
    		{9, lazy {:node, g, tree4(s, g), tree4(s, g)}}
    	]

    @doc """
    The trees grow too fast: we should distribute the size evenly to all subtrees
    """
    def tree5(g), do: sized(s, tree5(s, g))
    def tree5(0, _), do: :leaf
    def tree5(s, g), do:
    	frequency [
    		{1, tree5(0, g)},
    		{9, lazy {:node, g, tree5(div(s, 2), g), tree5(div(s, 2), g)}}
    	]

    @doc """
    Finally, we set up a more efficient shrinking strategy: pick each of the
    subtrees in place of the tree that fails the property.
    """
    def tree6(g), do: sized(s, tree6(s, g))
    def tree6(0, _), do: :leaf
    def tree6(s, g), do:
    	frequency [
    		{1, tree6(0, g)},
    		{9, letshrink([l, r] = [tree6(div(s, 2), g), tree6(div(s, 2), g)]) do
    				{:node, g, l, r}
    			end
    			}
    	]

end
