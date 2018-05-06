defmodule PropCheck.Test.BasicTypes do
  use ExUnit.Case
  use PropCheck

  doctest(PropCheck.BasicTypes)

  #########
  # Symbolic calls
  # as explained in http://propertesting.com/book_custom_generators.html#_symbolic_calls
  # work also in PropCheck.
  def dict_autosymb(), do:
    sized(size, dict_autosymb(size, {:"$call", :dict, :new, []}))
  def dict_autosymb(0, dict), do: dict
  def dict_autosymb(n, dict), do:
    dict_autosymb(n-1, {:"$call", :dict, :store, [integer(), integer(), dict]})

  property "symbolic auto calls on dict - expected to fail" do
    forall d <- dict_autosymb() do
      :dict.size(d) < 5
    end
    |> fails
  end

end
