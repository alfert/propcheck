defmodule UtilsTest do
  use ExUnit.Case

  alias PropCheck.Utils

  def adj_map_2_edges(adj_map) do
    adj_map
    |> Enum.flat_map(fn {k, v} -> Enum.map(v, &{k, &1}) end)
  end

  def wiki_graph do
    adj_map = %{
      a: [:b, :c, :e],
      b: [:d],
      c: [:d, :e],
      d: [:e],
      e: []
    }

    Graph.new(type: :directed)
    |> Graph.add_vertices(Map.keys(adj_map))
    |> Graph.add_edges(adj_map_2_edges(adj_map))

  end

  def complex_wiki_graph do
    adj_map = %{
      :a => [:d, :e],
      :b => [:d],
      :c => [:e, :h],
      :d => [:f, :g, :h],
      :e => [:g],
      :f => [],
      :g => [],
      :h => []
    }

    Graph.new(type: :directed)
    |> Graph.add_vertices(Map.keys(adj_map))
    |> Graph.add_edges(adj_map_2_edges(adj_map))
  end

  test "topological levels" do
    {:ok, levels} = Utils.toplevels(complex_wiki_graph())
    assert levels == [[:c, :b, :a], [:e, :d], [:h, :g, :f]]
  end

  def qfunc do
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
