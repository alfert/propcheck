defmodule PropCheck.Test.Tree do
  @moduledoc """
  The tree implementation of 2013 tutorial, Elixir version.
  """

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
  def delete2({:node, x, l, r}, x), do: join(delete2(l, x), delete2(r, x))
  def delete2({:node, y, l, r}, x), do: {:node, y, delete2(l, x), delete2(r, x)}

  @spec tree_sum(tree(number)) :: number
  def tree_sum(:leaf), do: 0
  def tree_sum({:node, x, l, r}), do: x + tree_sum(l) + tree_sum(r)

  @spec pre_order(tree(t)) :: [t] when t: var
  def pre_order(:leaf), do: []
  def pre_order({:node, x, l, r}), do: [x] ++ pre_order(l) ++ pre_order(r)
end
