defmodule PropCheck.Test.BasicTypes do
  @moduledoc """
  Tests for the basic generators or types, Mostly delegated as doctest to `PropCheck.BasicTypes?.
  """
  use ExUnit.Case, async: true
  use PropCheck, default_opts: &PropCheck.TestHelpers.config/0

  doctest(PropCheck.BasicTypes)

  #########
  # Symbolic calls
  # as explained in http://propertesting.com/book_custom_generators.html#_symbolic_calls
  # work also in PropCheck.
  def dict_autosymb, do: sized(size, dict_autosymb(size, {:"$call", :dict, :new, []}))
  def dict_autosymb(0, dict), do: dict

  def dict_autosymb(n, dict),
    do: dict_autosymb(n - 1, {:"$call", :dict, :store, [integer(), integer(), dict]})

  property "symbolic auto calls on dict - expected to fail" do
    forall d <- dict_autosymb() do
      :dict.size(d) < 5
    end
    |> fails
  end

  # Ensure that simple pos_integers() works - which it seems not to do: #211
  property "let with pos_integer fails", [:verbose] do
    our_list = let count <- pos_integer() do
      (1..count) |> Enum.to_list()
    end

    forall l <- our_list do
      (length(l) >= 1)
      |> measure("PosInt List length", length l)
      |> collect(length l)
    end
  end

  property "boom since you should not use produce/1 in generators" do
    gen = let x <-  binary() do
      {:ok, some_other} = produce(binary())
      {x, some_other}
    end

    forall {x, y} <- gen do
      x + y >= 0
    end
    |> fails
  end


end
