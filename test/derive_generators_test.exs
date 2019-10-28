defmodule DeriveGeneratorsTest do
  # Test deriving generators from @type definitions
  use ExUnit.Case
  use PropCheck

  alias PropCheck.DeriveGenerators

  # We can apply this to modules outside our control as well.
  use DeriveGenerators, module: String, only: [t: 0]
  use DeriveGenerators, module: Keyword

  alias SampleModule.Generate

  property "generator for all defined types is built" do
    forall _val <- Generate.all() do
      true
    end
  end

  describe "basic types" do
    property "anys" do
      forall _a <- Generate.anys() do
        true
      end
    end

    property "atoms" do
      forall a <- Generate.atoms() do
        is_atom(a)
      end
    end

    property "special_atom_literals" do
      forall a <- Generate.special_atom_literals() do
        a in [true, false, nil]
      end
    end

    property "maps" do
      forall m <- Generate.maps() do
        is_map(m)
      end
    end

    property "structs" do
      forall m <- Generate.structs() do
        is_map(m) && Map.has_key?(m, :__struct__)
      end
    end

    property "tuples" do
      forall t <- Generate.tuples() do
        is_tuple(t)
      end
    end

    property "integers" do
      forall i <- Generate.integers() do
        is_integer(i)
      end
    end

    property "floats" do
      forall f <- Generate.floats() do
        is_float(f)
      end
    end

    property "non_neg_integers" do
      forall i <- Generate.non_neg_integers() do
        is_integer(i) && i >= 0
      end
    end

    property "pos_integers" do
      forall i <- Generate.pos_integers() do
        is_integer(i) && i > 0
      end
    end

    property "neg_integers" do
      forall i <- Generate.neg_integers() do
        is_integer(i) && i < 0
      end
    end

    property "lists_integers" do
      forall l <- Generate.lists_integers() do
        Enum.all?(l, &is_integer/1)
      end
    end

    property "lists" do
      forall l <- Generate.lists(number()) do
        Enum.all?(l, &is_number/1)
      end
    end

    property "nonempty_lists" do
      forall l <- Generate.nonempty_lists(number()) do
        l != []
      end
    end

    property "maybe_improper_lists" do
      forall l <- Generate.maybe_improper_lists(number(), atom()) do
        case l do
          [] ->
            true

          _ ->
            last = maybe_improper_last(l)
            is_number(last) || is_atom(last)
        end
      end
    end

    property "nonempty_improper_lists" do
      forall l <- Generate.nonempty_improper_lists(number(), atom()) do
        l |> maybe_improper_last() |> is_atom()
      end
    end

    property "nonempty_maybe_improper_lists" do
      forall l <- Generate.nonempty_maybe_improper_lists(number(), atom()) do
        last = maybe_improper_last(l)
        is_number(last) || is_atom(last)
      end
    end
  end

  defp maybe_improper_last([last]), do: last
  defp maybe_improper_last([_ | t]), do: maybe_improper_last(t)
  defp maybe_improper_last(t), do: t

  describe "Literals" do
    property "atom_literal" do
      forall a <- Generate.atom_literals() do
        a == :atom
      end
    end

    property "empty_bitstrings" do
      forall b <- Generate.empty_bitstrings() do
        <<>> == b
      end
    end

    property "sized_bitstrings" do
      forall b <- Generate.sized_bitstrings() do
        is_bitstring(b) && bit_size(b) == 5
      end
    end

    property "unit_bitstrings" do
      forall b <- Generate.unit_bitstrings() do
        is_bitstring(b) && rem(bit_size(b), 10) == 0
      end
    end

    property "sized_unit_bitstrings" do
      forall b <- Generate.sized_unit_bitstrings() do
        is_bitstring(b) && bit_size(b) == 50
      end
    end

    property "zero_aritys" do
      forall f <- Generate.zero_aritys() do
        is_function(f, 0)
      end
    end

    property "two_aritys" do
      forall f <- Generate.two_aritys() do
        is_function(f, 2)
      end
    end

    property "empty_lists" do
      forall l <- Generate.empty_lists() do
        is_list(l) && l == []
      end
    end

    property "any_number_lists" do
      forall l <- Generate.any_number_lists() do
        Enum.all?(l, &is_number/1)
      end
    end

    property "nonempty_lists_with_any" do
      forall l <- Generate.nonempty_lists_with_any() do
        is_list(l) && l != []
      end
    end

    property "nonempty_lists_with_type" do
      forall l <- Generate.nonempty_lists_with_type(integer()) do
        is_list(l) && l != [] && Enum.all?(l, &is_integer/1)
      end
    end

    property "keyword_lists" do
      forall kw <- Generate.keyword_lists(integer()) do
        Enum.all?(kw, fn {key, value} ->
          is_atom(key) && is_integer(value)
        end)
      end
    end

    property "empty_maps" do
      forall m <- Generate.empty_maps() do
        m == %{}
      end
    end

    property "map_with_key" do
      forall m <- Generate.map_with_key(integer(), float()) do
        is_map(m) && is_integer(m[:key1]) && is_float(m[:key2])
      end
    end

    property "map_with_required_pairs" do
      forall m <- Generate.map_with_required_pairs(integer(), float()) do
        is_map(m) && Enum.all?(m, fn {k, v} -> is_integer(k) && is_float(v) end)
      end
    end

    property "map_with_optional_pairs" do
      forall m <- Generate.map_with_optional_pairs(integer(), float()) do
        is_map(m) && Enum.all?(m, fn {k, v} -> is_integer(k) && is_float(v) end)
      end
    end

    property "a_particular_struct_with_required_key" do
      forall s <- Generate.a_particular_struct_with_required_key(integer()) do
        is_map(s) && Map.get(s, :__struct__) == SampleModule.SomeStruct &&
          is_integer(Map.get(s, :key))
      end
    end

    property "any_particular_struct" do
      forall s <- Generate.any_particular_struct() do
        is_map(s) && Map.get(s, :__struct__) == SampleModule.SomeStruct
      end
    end

    property "empty_tuples" do
      forall t <- Generate.empty_tuples() do
        t == {}
      end
    end

    property "two_element_tuples" do
      forall t <- Generate.two_element_tuples() do
        elem(t, 0) == :ok && elem(t, 1) |> is_integer()
      end
    end
  end

  describe "Built-In" do
    property "terms" do
      forall _t <- Generate.terms() do
        true
      end
    end

    property "aritys" do
      forall a <- Generate.aritys() do
        is_integer(a) && 0 <= a && a <= 255
      end
    end

    property "as_booleans" do
      forall b <- Generate.as_booleans(integer()) do
        is_integer(b)
      end
    end

    property "binaries" do
      forall b <- Generate.binaries() do
        is_binary(b)
      end
    end

    property "my_binary" do
      forall b <- Generate.my_binary() do
        is_binary(b)
      end
    end

    property "bitstrings" do
      forall b <- Generate.bitstrings() do
        is_bitstring(b)
      end
    end

    property "booleans" do
      forall b <- Generate.booleans() do
        b in [true, false]
      end
    end

    property "bytes" do
      forall b <- Generate.bytes() do
        is_integer(b) && b >= 0 && b <= 255
      end
    end

    property "chars" do
      forall c <- Generate.chars() do
        is_integer(c) && c >= 0 && c <= 0x10FFFF
      end
    end

    property "charlists" do
      forall l <- Generate.charlists() do
        is_list(l) &&
          Enum.all?(l, fn c ->
            is_integer(c) && c >= 0 && c <= 0x10FFFF
          end)
      end
    end

    property "nonempty_charlists" do
      forall l <- Generate.nonempty_charlists() do
        is_list(l) && l != [] &&
          Enum.all?(l, fn c ->
            is_integer(c) && c >= 0 && c <= 0x10FFFF
          end)
      end
    end

    property "any_keywords" do
      forall kw <- Generate.any_keywords() do
        is_list(kw) &&
          Enum.all?(kw, fn tuple -> tuple_size(tuple) == 2 && is_atom(elem(tuple, 0)) end)
      end
    end

    property "keywords" do
      forall kw <- Generate.keywords(integer()) do
        is_list(kw) &&
          Enum.all?(kw, fn tuple ->
            tuple_size(tuple) == 2 &&
              is_atom(elem(tuple, 0)) &&
              is_integer(elem(tuple, 1))
          end)
      end
    end

    property "any_lists" do
      forall l <- Generate.any_lists() do
        is_list(l)
      end
    end

    property "any_nonempty_lists" do
      forall l <- Generate.any_nonempty_lists() do
        is_list(l) && l != []
      end
    end

    property "any_nonempty_maybe_improper_list" do
      forall _l <- Generate.any_nonempty_maybe_improper_list() do
        true
      end
    end

    property "any_maybe_improper_lists" do
      forall _l <- Generate.any_maybe_improper_lists() do
        true
      end
    end

    property "mfas" do
      forall mfa <- Generate.mfas() do
        case mfa do
          {module, function, arity} ->
            is_atom(module) && is_atom(function) && is_integer(arity) && arity >= 0

          _ ->
            false
        end
      end
    end

    property "modules" do
      forall m <- Generate.modules() do
        is_atom(m)
      end
    end

    property "nodes" do
      forall n <- Generate.nodes() do
        is_atom(n)
      end
    end

    property "numbers" do
      forall n <- Generate.numbers() do
        is_number(n)
      end
    end

    property "timeouts" do
      forall t <- Generate.timeouts() do
        t == :infinity || (is_integer(t) && t >= 0)
      end
    end
  end

  describe "Remote Types" do
    test "String.t()" do
      forall s <- String.Generate.t() do
        is_binary(s)
      end
    end

    test "Keyword.t(type)" do
      forall kw <- Keyword.Generate.t(integer()) do
        is_list(kw) &&
          Enum.all?(fn tuple ->
            tuple_size(tuple) == 2 &&
              is_atom(elem(tuple, 0)) &&
              is_integer(elem(tuple, 1))
          end)
      end
    end
  end
end

defmodule SampleModule do
  # https://hexdocs.pm/elixir/typespecs.html
  #
  # FIXME for types which cannot be generated, add a generator which takes a constant as an argument
  #  so that a user can pass that in (only useful if the type is nested!)

  # UNSUPPORTED @type nones :: none()

  use PropCheck.DeriveGenerators

  #
  # Basic Types
  #
  @type anys :: any()
  @type atoms :: atom()
  @type maps :: map()
  # UNSUPPORTED @type pids :: pid()
  # UNSUPPORTED @type ports :: port()
  # UNSUPPORTED @type references :: reference()
  @type structs :: struct()
  @type tuples :: tuple()

  @type integers :: integer()
  @type floats :: float()
  @type non_neg_integers :: non_neg_integer()
  @type pos_integers :: pos_integer()
  @type neg_integers :: neg_integer()

  @type lists_integers :: list(integer())
  @type lists(type) :: list(type)
  @type nonempty_lists(type) :: nonempty_list(type)
  @type maybe_improper_lists(type1, type2) :: maybe_improper_list(type1, type2)
  @type nonempty_improper_lists(type1, type2) :: nonempty_improper_list(type1, type2)
  @type nonempty_maybe_improper_lists(type1, type2) :: nonempty_maybe_improper_list(type1, type2)

  #
  # Literals
  #

  ## Atoms
  @type atom_literals :: :atom
  @type special_atom_literals :: true | false | nil

  ## Bitstrings
  @type empty_bitstrings :: <<>>
  @type sized_bitstrings :: <<_::5>>
  @type unit_bitstrings :: <<_::_*10>>
  @type sized_unit_bitstrings :: <<_::5, _::_*10>>

  ## (Anonymous) Functions

  @type zero_aritys :: (() -> any())
  @type two_aritys :: (any(), any() -> any())
  # NOT SUPPORTED: @type any_aritys :: (... -> any()) (AST does not contain result type)

  ## Lists
  @type empty_lists :: []
  @type any_number_lists :: [integer()]
  @type nonempty_lists_with_any :: [...]
  @type nonempty_lists_with_type(type) :: [type, ...]
  @type keyword_lists(value_type) :: [key1: value_type, key2: value_type]

  defmodule SomeStruct do
    # Helper for %SomeStruct{} type
    defstruct [:key]
  end

  ## Maps
  @type empty_maps :: %{}
  @type map_with_key(type1, type2) :: %{key1: type1, key2: type2}
  @type map_with_required_pairs(key_type, value_type) :: %{required(key_type) => value_type}
  @type map_with_optional_pairs(key_type, value_type) :: %{optional(key_type) => value_type}
  @type any_particular_struct :: %SomeStruct{}
  @type a_particular_struct_with_required_key(value_type) :: %SomeStruct{key: value_type}

  ## Tuples

  @type empty_tuples :: {}
  @type two_element_tuples :: {:ok, integer()}

  #
  # Built-In
  #

  @type terms :: term()
  @type aritys :: arity()
  @type as_booleans(t) :: as_boolean(t)
  @type binaries :: binary()
  @type bitstrings :: bitstring()
  @type booleans :: boolean()
  @type bytes :: byte()
  @type chars :: char()
  @type charlists :: charlist()
  @type nonempty_charlists :: nonempty_charlist()
  # NOT SUPPORTED fun() :: (... -> any)
  # NOT SUPPORTED function() :: fun()
  # NOT SUPPORTED identifier() :: pid() | port() | reference()
  # NOT SUPPORTED iodata :: iolist() | binary()
  # NOT SUPPORTED iolist :: maybe_improper_list(byte() | binary() | iolist(), binary() | [])
  @type any_keywords :: keyword()
  @type keywords(type) :: keyword(type)
  @type any_lists :: list()
  @type any_nonempty_lists :: nonempty_list()
  @type any_maybe_improper_lists() :: maybe_improper_list()
  @type any_nonempty_maybe_improper_list :: nonempty_maybe_improper_list()
  @type mfas :: mfa()
  @type modules :: module()
  # NOT SUPPORTED no_return() :: none()
  @type nodes :: node()
  @type numbers :: number()
  # Part of basic types:  struct() :: %{:__struct__ => atom(), optional(atom()) => any()}
  @type timeouts :: timeout()

  # Remote Types

  @type my_string :: String.t()
  @type my_keyword(type) :: Keyword.t(type)

  # Referring to user-defined types
  @type my_binary :: binaries()
end
