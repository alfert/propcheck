defmodule UtilsTest do
  use ExUnit.Case

  alias PropCheck.Utils

  def wiki_graph do
    {:out, %{
      a: [:b, :c, :e],
      b: [:d],
      c: [:d, :e],
      d: [:e],
      e: []
    }}
  end

  def complex_wiki_graph do
    {:out, %{
      :a => [:d, :e],
      :b => [:d],
      :c => [:e, :h],
      :d => [:f, :g, :h],
      :e => [:g],
      :f => [],
      :g => [],
      :h => []
    }}
  end

  def inverted_wiki_graph do
    {:in, %{
      e: [:d, :c, :a],
      d: [:c, :b],
      c: [:a],
      b: [:a],
      a: []
    }}
  end

  def top_check(graph = {:in, _}, order), do: top_check(Utils.invert_graph(graph), order)
  def top_check({:out, graph}, order) do
    vert_2_order = order |> Enum.with_index() |> Map.new()
    check_vert_order = fn {k, inds} ->
      ko = vert_2_order[k]
      Enum.all?(inds, fn x -> ko < vert_2_order[x] end)
    end

    Enum.all?(graph, check_vert_order)
  end

  test "invert wiki graph" do
    assert Utils.invert_graph(wiki_graph()) == inverted_wiki_graph()
  end

  test "double invert" do
    as_set = fn {k, v} ->
      {k, MapSet.new(v)}
    end
    fuzzy_wiki_graph = wiki_graph() |> elem(1) |> Map.new(as_set)
    fuzzy_double_inverted =
      wiki_graph()
      |> Utils.invert_graph()
      |> Utils.invert_graph()
      |> elem(1)
      |> Map.new(as_set)
    assert fuzzy_wiki_graph == fuzzy_double_inverted
  end

  test "topsort wiki graph" do
    {:ok, sorted} = Utils.topsort(wiki_graph())
    assert top_check(wiki_graph(), sorted)

    {:ok, sorted} = Utils.topsort(inverted_wiki_graph())
    assert top_check(inverted_wiki_graph(), sorted)
  end

  test "topsort complex wiki graph" do
    {:ok, sorted} = Utils.topsort(complex_wiki_graph())
    assert top_check(complex_wiki_graph(), sorted)

    {:ok, sorted} = complex_wiki_graph() |> Utils.invert_graph() |> Utils.topsort()
    assert top_check(complex_wiki_graph(), sorted)
  end

  test "topological levels" do
    {:ok, levels} = Utils.toplevels(complex_wiki_graph())
    assert levels == [[:a, :b, :c], [:d, :e], [:f, :g, :h]]
  end

  def qfunc() do
    quote do
      foo(a + 1, bar(b, {dd, q}), ^c)
    end
  end

  test "find all vars" do
    vars = Utils.find_all_vars(qfunc())
    assert vars == [{:^, :c}, :q, :dd, :b, :a]
  end

  test "replace_pinned" do
    unpinned =
      qfunc()
      |> Utils.unpin_vars()
      |> Macro.to_string()
    assert "foo(a + 1, bar(b, {dd, q}), c)" == unpinned
  end

end
