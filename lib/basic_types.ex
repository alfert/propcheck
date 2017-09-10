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

  @typedoc "Non negative integers extend by infinity"
  @type ext_non_neg_integer :: non_neg_integer | :inf

  @typedoc "Floats extend by infinity"
  @type ext_float :: float | :inf

  @typedoc "The internal representation of a basic type in PropEr"
  @opaque raw_type :: :proper_types.raw_type

  @typedoc "The internal representation of a type in PropEr"
  @opaque type :: type

  @type frequency :: pos_integer

  @type size :: PropCheck.size
  @type value :: any

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

  **CAUTION:** Instances of this type are expensive to produce, shrink and instance-
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

  @doc "All integers, i.e. `integer(:inf, :inf)`"
  @spec integer() :: type
  def integer(), do: integer(:inf, :inf)
  @doc "Strictly positive integers, i.e. `integer(1, :inf)`"
  @spec pos_integer :: type
  def pos_integer(), do: integer(1, :inf)
  @doc "Non negative integers, i.e. `integer(0, :inf)`"
  @spec non_neg_integer :: type
  def non_neg_integer(), do: integer(0, :inf)
  @doc "Negative integers, i.e. `integer(:inf, -1)`"
  @spec neg_integer :: type
  def neg_integer(), do: integer(:inf, -1)

  @doc "A range is equivalent to integers"
  @spec range(ext_int, ext_int) ::type
  def range(low, high), do: integer(low, high)

  @doc "All floats, i.e. `float(:inf, :inf)`"
  @spec float() :: type
  def float(), do: float(:inf, :inf)
  @doc "Non negative floats, i.e. `float(0.0, inf)`"
  @spec non_neg_float() :: type
  def non_neg_float(), do: float(0.0, :inf)

  @doc "Numbers are integers or floats, i.e. `union([integer(), float()])`"
  @spec number() :: type
  def number(), do: union([integer(), float()])

  @doc "The atoms `true` and `false`. Instances shrink towards `false`."
  @spec boolean() :: type
  def boolean(), do: union([false, true])

  @doc "Byte values, i.e. `integer(0, 255)`"
  @spec byte() :: type
  def byte(), do: integer(0, 255)

  @doc "Char values (16 bit for some reason), i.e. `integer(0, 0xffff)`"
  @spec char() :: type
  def char(), do: integer(0, 0xffff)


  @doc """
  Bounded upper size utf8 binary, `codepoint length =< MaxCodePointSize`.

  Limiting codepoint size can be useful when applications do not accept full
  unicode range. For example, MySQL in utf8 encoding accepts only 3-byte
  unicode codepoints in VARCHAR fields.

  If unbounded length is needed, use `:inf` as first argument.
  """
  @spec utf8(ext_non_neg_integer, 1..4) :: type
  def utf8(n, max_codepoint_size), do:
    :proper_unicode.utf8(n, max_codepoint_size)

  @doc "utf8-encoded unbounded size binary"
  @spec utf8() :: type
  def utf8(), do: utf8(:inf, 4)

  @doc "utf8-encoded bounded upper size binary."
  @spec utf8(ext_non_neg_integer) :: type
  def utf8(n), do: utf8(n, 4)

  @doc "List of any types, i.e. `list(any)`"
  @spec list() :: type
  def list(), do: list(any())

  @doc "Tuples of any types, i.e. `loose_tuple(any)`"
  @spec tuple() :: type
  def tuple(), do: loose_tuple(any())

  @doc "An Erlang string, i.e. `list(char)`"
  @spec char_list() :: type
  def char_list(), do: list(char())

  @doc "weighted_union(FreqChoices)"
  @spec wunion([{frequency,raw_type},...]) :: type
  def wunion(freq_choices), do: weighted_union(freq_choices)

  @doc "Term is a synonym for `any`"
  @spec term() :: type
  def term(), do: any()

  @doc "timeout values, i.e. `union([non_neg_integer() | :infinity])`"
  @spec timeout() :: type
  def timeout(), do: union([non_neg_integer(), :infinity])

  @doc "Arity is a byte value, i.e. `integer(0, 255)`"
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
  def large_int(), do: integer()

  @doc "real is equivalent to `float`"
  @spec real() :: type
  def real(), do: float()

  @doc "bool is equivalent to `boolean`"
  @spec bool() :: type
  def bool(), do: boolean()

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

  @doc """
  A specialization of `default/2`.

  Parameters `default` and `type` are
  assigned weights to be considered by the random instance generator. The
  shrinking subsystem will ignore the weights and try to shrink using the
  default value.
  """
  @spec weighted_default({frequency,raw_type}, {frequency,raw_type}) :: type
  def weighted_default(default, type), do: weighted_union([default, type])

  @doc "A function with 0 parameters, i.e. `function(0, ret_type)`"
  @spec function0(type) :: type
  def function0(ret_type), do: function(0, ret_type)

  @doc "A function with 1 parameter, i.e. `function(1, ret_type)`"
  @spec function1(type) :: type
  def function1(ret_type), do: function(1, ret_type)
  @doc "A function with 2 parameters, i.e. `function(2, ret_type)`"
  @spec function2(type) :: type
  def function2(ret_type), do: function(2, ret_type)
  @doc "A function with 3 parameters, i.e. `function(3, ret_type)`"
  @spec function3(type) :: type
  def function3(ret_type), do: function(3, ret_type)
  @doc "A function with 4 parameters, i.e. `function(4, ret_type)`"
  @spec function4(type) :: type
  def function4(ret_type), do: function(4, ret_type)

  #######################################################
  #
  # Additional type specification functions
  #
  #######################################################
  @doc """
  Overrides the `size` parameter used when generating instances of
  `type` with `new_size`.

  Has no effect on size-less types, such as unions.
  Also, this will not affect the generation of any internal types contained in
  `type`, such as the elements of a list - those will still be generated
  using the test-wide value of `size`. One use of this function is to modify
  types to produce instances that grow faster or slower, like so:

      iex> quickcheck(forall l <- list(integer()) do
      ...>   length(l) <= 42
      ...> end)
      true

      iex> long_list = sized(size, resize(size * 2, list(integer())))
      iex> really_long = such_that_maybe l <- long_list, when:
      ...>      length(l) > 42
      iex> quickcheck(forall l <- really_long do
      ...>   (length(l) <= 84)
      ...>   |> measure("List length", length l)
      ...>   |> collect(length l)
      ...> end)
      true

  The above specifies a list type that grows twice as fast as normal lists.
  """
  @spec resize(size, raw_type) :: type
  defdelegate resize(new_size, raw_type), to: :proper_types

  @doc """
  This is a predefined constraint that can be applied to random-length
  list and binary types to ensure that the produced values are never empty.

  Use for e.g. `list/0`, `char_list/0`, `binary/0`
  """
  @spec non_empty(raw_type) :: type
  def non_empty(list_type) do
    such_that l <- list_type, when: l != [] and l != <<>>
  end

  @doc """
  Creates a new type which is equivalent to `type`, but whose instances
  are never shrunk by the shrinking subsystem.
  """
  @spec noshrink(raw_type) :: type
  defdelegate noshrink(type), to: :proper_types

  @doc """
  Associates the atom key `parameter` with the value `value` while
  generating instances of `type`.
  """
  @spec with_parameter(atom, value, raw_type) :: type
  def with_parameter(parameter, value, type), do:
      with_parameters([{parameter,value}], type)

  @doc """
  Similar to `with_parameter/3`, but accepts a list of
  `{parameter, value}` pairs.
  """
  @spec with_parameters([{atom, value}], raw_type) :: type
  defdelegate with_parameters(pv_list, type), to: :proper_types

  @doc """
  Returns the value associated with `parameter`, or `:undefined` in case
  `parameter` is not associated with any value.

  Association occurs with calling `with_parameter/3` or `with_parameters/2`
  before.
  """
  @spec parameter(atom) :: value
  def parameter(parameter), do: parameter(parameter, :undefined)
  @doc """
  Returns the value associated with `parameter`, or `default` in case
  `parameter` is not associated with any value.

  Association occurs with calling `with_parameter/3` or `with_parameters/2`
  before.
  """
  @spec parameter(atom, value) :: value
  defdelegate parameter(parameter, default), to: :proper_types

end
