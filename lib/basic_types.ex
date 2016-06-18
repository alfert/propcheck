defmodule PropCheck.BasicTypes do
  @moduledoc """
  This modules contains all basic type generators from PropEr. It is
  automatically available by `use PropCheck`.


  ## Acknowlodgements

  The functions defined here are delegated to the corresponding
  definition `proper_types`. Also most of the documentation is
  copied over from there.

  """
  import PropCheck

  @typedoc "Integers extend by infinity"
  @type ext_int :: integer | :inf

  @typedoc "Floats extend by infinity"
  @type ext_float :: float | :inf

  @typedoc "The internal representation of a basic type in PropEr"
  @opaque raw_type :: :proper_types.raw_type

  @typedoc "The internal representation of a type in PropEr"
  @opaque type :: type

  @type frequency :: pos_integer


  @doc """
  All integers between `low` and `high`, bounds included.

  `low` and `high` must be Elixir expressions that evaluate to integers, with
  `low =< high`. Additionally, `low` and `high` may have the value `:inf`, in
  which case they represent minus infinity and plus infinity respectively.
  Instances shrink towards 0 if `low =< 0 =< high`, or towards the bound with
  the smallest absolute value otherwise.
  """
  @spec integer(ext_int, ext_int) :: type
  defdelegate integer(low, high), to: :proper_types

  @doc """
  All floats between `low` and `high`, bounds included.

  `low` and `high` must be Elixir expressions that evaluate to floats, with
  `Low =< high`. Additionally, `low` and `high` may have the value `:inf`, in
  which case they represent minus infinity and plus infinity respectively.
  Instances shrink towards 0.0 if `low =< 0.0 =< high`, or towards the bound
  with the smallest absolute value otherwise.
  """
  @spec float(ext_float, ext_float) :: type
  defdelegate float(low, high), to: :proper_types

  @doc """
  All atoms.

  All atoms used internally by PropEr start with a `:$` , so
  such atoms will never be produced as instances of this type. You should also
  refrain from using such atoms in your code, to avoid a potential clash.
  Instances shrink towards the empty atom, `:""`.
  """
  @spec atom :: type
  defdelegate atom(), to: :proper_types

  @doc """
  All binaries.

  Instances shrink towards the empty binary, `""`.
  """
  @spec binary() :: type
  defdelegate binary(), to: :proper_types

  @doc """
  All binaries with a byte size of `length`.

  `length` must be an Elixir expression that evaluates to a non-negative integer.
  Instances shrink towards binaries of zeroes.
  """
  @spec binary(non_neg_integer) :: type
  defdelegate binary(length), to: :proper_types

  @doc """
  All bitstrings.

  Instances shrink towards the empty bitstring, `""`.
  """
  @spec bitstring() :: type
  defdelegate bitstring(), to: :proper_types

  @doc """
  All bitstrings with a byte size of `length`.

  `length` must be an Elixir expression that evaluates to a non-negative integer.
  Instances shrink towards bitstrings of zeroes.
  """
  @spec bitstring(non_neg_integer) :: type
  defdelegate bitstring(length), to: :proper_types


  @doc """
  All lists containing elements of type `elem_type`.

  Instances shrink towards the empty list, `[]`.
  """
  @spec list(raw_type) :: type
  defdelegate list(elem_type), to: :proper_types


  @doc """
  A type that generates exactly the list `list`.

  Instances shrink towards shorter sublists of the original list.
  """
  @spec shrink_list([any]) :: type
  defdelegate shrink_list(list), to: :proper_types

  @doc """
  All lists of length `length` containing elements of type `elem_type`.

  `length` must be an Elixir expression that evaluates to a non-negative integer.
  """
  @spec vector(non_neg_integer, raw_type) :: type
  defdelegate vector(length, elem_type), to: :proper_types

  @doc """
  The union of all types in `list_of_types`.

  `list_of_types` can't be empty.
  The random instance generator is equally likely to choose any one of the
  types in `list_of_types`. The shrinking subsystem will always try to shrink an
  instance of a type union to an instance of the first type in `list_of_types`,
  thus you should write the simplest case first.
  """
  @spec union([raw_type,...]) :: type
  defdelegate union(list_of_types), to: :proper_types

  @doc """
  A specialization of `union/1`, where each type in `list_of_types` is
  assigned a frequency.

  Frequencies must be Elixir expressions that evaluate to
  positive integers. Types with larger frequencies are more likely to be chosen
  by the random instance generator. The shrinking subsystem will ignore the
  frequencies and try to shrink towards the first type in the list.
  """
  @spec weighted_union([{frequency, raw_type},...]) :: type
  defdelegate weighted_union(list_of_types), to: :proper_types


  @doc """
  All tuples whose i-th element is an instance of the type at index i of
  `list_of_types`.

   Also written simply as a tuple of types.
  """
  @spec tuple([raw_type()]) :: type
  defdelegate tuple(list_of_types), to: :proper_types

  @doc """
  Tuples whose elements are all of type `elem_type`.

  Instances shrink towards the 0-size tuple, `{}`.
  """
  @spec loose_tuple(raw_type()) :: type
  defdelegate loose_tuple(elem_type), to: :proper_types

  @doc """
  Singleton type consisting only of `value`.

  `value` must be an evaluated term. Also written simply as `value`.
  """
  @spec exactly(any) :: type
  defdelegate exactly(value), to: :proper_types


  @doc """
  All lists whose i-th element is an instance of the type at index i of
 ``list_of_types`. Also written simply as a list of types.
  """
  @spec fixed_list([raw_type()]) :: type
  defdelegate fixed_list(list_of_types), to: :proper_types

  @doc """
  All pure functions that map instances of `arg_types` to instances of
  `ret_type`.

  The syntax `function(arity, ret_type)` is also acceptable.
  """
  @spec function([raw_type] | arity, raw_type) :: type
  defdelegate function(arg_types, return_type), to: :proper_types

  @doc """
  All Elixir terms (that PropEr can produce).

  For reasons of efficiency, functions are never produced as instances of
  this type.
  *CAUTION:* Instances of this type are expensive to produce, shrink and instance-
  check, both in terms of processing time and consumed memory. Only use this
  type if you are certain that you need it.
  """
  @spec any() :: type
  defdelegate any(), to: :proper_types

  ################################################
  #
  # Type aliases
  #
  ###############################################

  @doc "All integers: `integer(:inf, :inf)`"
  @spec integer() :: type
  def integer(), do: integer(:inf, :inf)
  @doc "Strictly positive integers: `integer(1, :inf)`"
  @spec pos_integer :: type
  def pos_integer(), do: integer(1, :inf)
  @doc "Non negative integers: `integer(0, :inf)`"
  @spec non_neg_integer :: type
  def non_neg_integer(), do: integer(0, :inf)
  @doc "Negative integers: `integer(:inf, -1)`"
  @spec neg_integer :: type
  def neg_integer(), do: integer(:inf, -1)

  @doc "A range is equivalent to integers"
  @spec range(ext_int, ext_int) ::type
  def range(low, high), do: integer(low, high)

  @doc "All floats: `float(:inf, :inf)`"
  @spec float() :: type
  def float(), do: float(:inf, :inf)
  @doc "Non negative floats: `float(0.0, inf)`"
  @spec non_neg_float() :: type
  def non_neg_float(), do: float(0.0, :inf)

  @doc "Numbers are integers or floats: `union([integer(), float()])`"
  @spec number() :: type
  def number(), do: union([integer(), float()])

  @doc "The atoms `true` and `false`. Instances shrink towards `false`."
  @spec boolean() :: type
  def boolean(), do: union([false, true])

  @doc "Byte values: `integer(0, 255)`"
  @spec byte() :: type
  def byte(), do: integer(0, 255)

  @doc "Char values (16 bit for some reason): `integer(0, 0xffff)`"
  @spec char() :: type
  def char(), do: integer(0, 0xffff)

  @doc "List of any types: `list(any)`"
  @spec list() :: type
  def list(), do: list(any)

  @doc "Tuples of any types: `loose_tuple(any)`"
  @spec tuple() :: type
  def tuple(), do: loose_tuple(any)

  @doc "An Erlang string: `list(char)`"
  @spec char_list() :: type
  def char_list(), do: list(char)

  @doc "weighted_union(FreqChoices)"
  @spec wunion([{frequency,raw_type},...]) :: type
  def wunion(freq_choices), do: weighted_union(freq_choices)

  @doc "Term is a synonym for `any`"
  @spec term() :: type
  def term(), do: any

  @doc "timeout values: `union([non_neg_integer() | :infinity])`"
  @spec timeout() :: type
  def timeout(), do: union([non_neg_integer(), :infinity])

  @doc "Arity is a byte value: `integer(0, 255)`"
  @spec arity() :: type
  def arity(), do: integer(0, 255)

  ################################################
  #
  # QuickCheck compatability aliases
  #
  ###############################################

  @doc """
  Small integers (bound by the current value of the `size` parameter).

  Instances shrink towards `0`.
  """
  @spec int() :: type
  def int(), do: sized(size, integer(-size, size))

  @doc """
  Small Small non-negative integers (bound by the current value of the `size`
   parameter).

  Instances shrink towards `0`.
  """
  @spec nat() :: type
  def nat(), do: sized(size, integer(0, size))

  @doc "Large_int is equivalent to `integer`"
  @spec large_int() :: type
  def large_int(), do: integer

  @doc "real is equivalent to `float`"
  @spec real() :: type
  def real(), do: float

  @doc "bool is equivalent to `boolean`"
  @spec bool() :: type
  def bool(), do: boolean

  @doc "choose is equivalent to `integer(low, high)`"
  @spec choose(ext_int, ext_int) :: type
  def choose(low, high), do: integer(low, high)

  @doc "elements is equivalent to `union([..])`"
  @spec elements([raw_type,...]) :: type
  def elements(choices), do: union(choices)

  @doc "oneof is equivalent to `union([..])`"
  @spec oneof([raw_type,...]) :: type
  def oneof(choices), do: union(choices)

  @doc "frequency is equivalent to `weighted_union([..])`"
  @spec frequency([{frequency,raw_type},...]) :: type
  def frequency(freq_choices), do: weighted_union(freq_choices)

  @doc "return is equivalent to `exactly`"
  @spec return(any) :: type
  def return(e), do: exactly(e)

  @doc """
  Adds a default value, `default_value`, to `type`.

  The default serves as a primary shrinking target for instances, while it
  is also chosen by the random instance generation subsystem half the time.
  """
  @spec default(raw_type, raw_type) :: type
  def default(default_value, type), do: union([default_value, type])

  @doc """
  All sorted lists containing elements of type `elem_type`.

  Instances shrink towards the empty list, `[]`.
  """
  @spec ordered_list(raw_type()) :: type
  def ordered_list(elem_type) do
    let l <- list(elem_type), do: :lists.sort(l)
  end



end
