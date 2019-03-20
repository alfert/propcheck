defmodule PropCheck.Test.Stack do

  @opaque stack(t) :: [t] # when t: var
  @opaque stack :: stack(any)

  @spec new(t) :: stack(t) when t: var
  def new(_) , do: []

  @spec push(stack(t), t) :: stack(t) when t: var
  def push(s, x), do: [x | s]

  @spec pop(stack(t)) :: {t, stack(t)} when t: var
  def pop([]), do: throw "Empty Stack"
  def pop([x | s]), do: {x, s}

  @spec empty(stack) :: boolean
  def empty([]), do: true
  def empty(_), do: false

  @spec size(stack) :: non_neg_integer
  def size(s), do: length s

end
