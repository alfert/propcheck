defmodule PropCheck.Test.TargetPathTest do
  @moduledoc """
  This is the initial example for Targeted Properties of Fred Hebert's book "
  Property Based Testing"
  """
  use PropCheck
  use ExUnit.Case

  require Logger

  def path(), do: list(oneof([:left, :right, :up, :down]))

  def move(:left, {x, y}),  do: {x-1, y}
  def move(:right, {x, y}), do: {x+1, y}
  def move(:up, {x, y}),    do: {x, y+1}
  def move(:down, {x, y}),  do: {x, y-1}


  property "trivial path", [:verbose, numtests: 10] do
    forall p <- path() do
      {x,y} = Enum.reduce(p, {0, 0}, &move/2)
      IO.write "(#{x},#{y})."
      true
    end
  end

  property "simple targeted path", [:verbose, search_steps: 100] do
    numtests(10,
    forall_targeted p <- path() do
      {x,y} = Enum.reduce(p, {0, 0}, &move/2)
      IO.write "(#{x},#{y})."
      maximize(x-y)
      true
    end
    )
  end

  @doc """
  Test there are is a path of `distance >= sqrt(100)`: Show that at least one path exists
  which is not smaller than `100` by testing that each path has a `distance_square < 100`.
  If this fails, then we have found at least one path that a greater distance than
  `distance_square < 100`.
  """
  property "reach a path of distance sqrt(100)", [:verbose, search_steps: 100] do
    forall_targeted p <- path() do
      {x,y} = Enum.reduce(p, {0, 0}, &move/2)
      IO.write "(#{x},#{y})."
      distance_square = (x*x + y*y)
      maximize(distance_square)
      distance_square < 100
    end
    |> fails()
  end

  @doc """
  Similar to the `forall_targeted` variant but using `exists`: Check that at least one path
  is has a `distance_square >= 100`.
  """
  property "exists: at least one path with distance >= sqrt(100) exists", [:verbose, search_steps: 100] do
    exists p <- path() do
      {x,y} = Enum.reduce(p, {0, 0}, &move/2)
      IO.write "(#{x},#{y})."
      distance_square = (x*x + y*y)
      maximize(distance_square)
      distance_square >= 100
    end
  end


end
