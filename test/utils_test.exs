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
      7 => [11, 8],
      5 => [11],
      3 => [8, 10],
      11 => [2, 9],
      8 => [9],
      2 => [],
      9 => [],
      10 => []
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

  def top_check({:in, _} = graph, order), do: top_check(Utils.invert_graph(graph), order)
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

end
