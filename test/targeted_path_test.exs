defmodule PropCheck.Test.TargetPathTest do
  @moduledoc """
  This is the initial example for Targeted Properties of Fred Hebert's book "
  Property Based Testing"
  """
  use PropCheck, default_opts: &PropCheck.TestHelpers.config/0
  use ExUnit.Case, async: true
  import PropCheck.TestHelpers, except: [config: 0]

  require Logger

  def path, do: list(oneof([:left, :right, :up, :down]))

  def move(:left, {x, y}), do: {x - 1, y}
  def move(:right, {x, y}), do: {x + 1, y}
  def move(:up, {x, y}), do: {x, y + 1}
  def move(:down, {x, y}), do: {x, y - 1}

  property "trivial path", [scale_numtests(0.1)] do
    forall p <- path() do
      {x, y} = Enum.reduce(p, {0, 0}, &move/2)
      debug("(#{x},#{y}).")
      true
    end
  end

  property "simple targeted path", [scale_numtests(0.1), scale_search_steps(0.1)] do
    forall_targeted p <- path() do
      {x, y} = Enum.reduce(p, {0, 0}, &move/2)
      debug("(#{x},#{y}).")
      maximize(x - y)
      true
    end
  end

  @doc """
  Test there are is a path of `distance >= sqrt(100)`: Show that at least one path exists
  which is not smaller than `100` by testing that each path has a `distance_square < 100`.
  If this fails, then we have found at least one path that a greater distance than
  `distance_square < 100`.
  """
  # this can fail on rare occasions
  property "reach a path of distance sqrt(100)", search_steps: 200 do
    forall_targeted p <- path() do
      {x, y} = Enum.reduce(p, {0, 0}, &move/2)
      debug("(#{x},#{y}).")
      distance_square = x * x + y * y
      maximize(distance_square)
      distance_square < 100
    end
    |> fails()
  end

  @doc """
  Similar to the `forall_targeted` variant but using `exists`: Check that at least one path
  is has a `distance_square >= 100`.
  """
  # this can fail on rare occasions
  property "exists: at least one path with distance >= sqrt(100) exists", search_steps: 200 do
    exists p <- path() do
      {x, y} = Enum.reduce(p, {0, 0}, &move/2)
      debug("(#{x},#{y}).")
      distance_square = x * x + y * y
      maximize(distance_square)
      distance_square >= 100
    end
  end
end
