defmodule PropCheck.TreeTest do
  @moduledoc """
  A set of properties for various tree implementations
  """
  use ExUnit.Case, async: true
  alias PropCheck.Test.Tree
  use PropCheck, default_opts: &PropCheck.TestHelpers.config/0
  import PropCheck.TestHelpers, except: [config: 0]

  ################################
  ### Properties of the tree

  # delete is faulty, therefore we expect it fail now and then
  property "delete" do
    # the faulty tree has a default-value, which occurs more often#
    # than other values. We also delete this default-value, hence
    # the buggy delete method should fail.
    faulty_tree = let x <- integer() do
      {x, tree(default(x, integer()))}
    end

    fails(forall {x, t} <- faulty_tree do
      not Tree.member(Tree.delete(t, x), x)
    end)

  end

  # delete2 is not faulty
  property "delete2", [max_size: 20]               do
    forall {x, t} <- {integer(), tree(integer())} do
      _tsize = t |> Tree.pre_order |> Enum.count
      (not Tree.member(Tree.delete2(t, x), x))
      # |> collect(tsize)
      # |> measure("Tree Size", tsize)
    end
  end

  # Example of a PBT strategy: finding two distinct computations that should
  # result in the same value.
  property "sum" do
    forall t <- tree(integer()) do
      Tree.pre_order(t) |> Enum.sum == Tree.tree_sum(t)
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
    frequency([
      {1, tree5(0, g)},
      {9, lazy {:node, g, tree5(div(s, 2), g), tree5(div(s, 2), g)}}
    ])

  @doc """
  Finally, we set up a more efficient shrinking strategy: pick each of the
  subtrees in place of the tree that fails the property.
  """
  def tree6(g), do: sized(s, tree6(s, g))
  def tree6(0, _), do: :leaf
  def tree6(s, g), do:
    frequency [
      {1, tree6(0, g)},
      {9, let_shrink([
          l <- tree6(div(s, 2), g),
          r <- tree6(div(s, 2), g)
        ]) do
          {:node, g, l, r}
        end
      }
    ]

end
