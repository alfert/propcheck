defmodule PropCheck.Support.InstrumentExample do

  @moduledoc """
  A module for instrumentation.
  """
  def hello(s) when is_binary(s) do
    IO.puts "Hello to #{s}"
    private_hello(s)
  end

  def hello, do: IO.puts "Hello"

  def fetch_from_ets(table, key) do
    [x] = :ets.lookup_element(table, key, 1)
    x
  end

  def put_to_ets(table, key, value) do
    :ets.update_element(table, key, value)
  end

  def ets_in_expr(table, key) do
    case :ets.lookup_element(table, key, 1) do
      [] -> "empty list"
      [1, 2, 3] -> "three values"
      l when is_list(l) -> "a value list"
      _v -> "a single value"
    end
  end

  defp private_hello(s) do
    IO.puts "Private Hello to #{s}"
  end
end
