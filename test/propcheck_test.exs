defmodule PropcheckTest do
  @moduledoc """
  Basic Tests for PropCheck, delegating mostly to doc tests.
  """
  use ExUnit.Case, async: true
  use PropCheck, default_opts: &PropCheck.TestHelpers.config/0
  import PropCheck.TestHelpers, except: [config: 0]

  import ExUnit.CaptureIO
  require Logger

  doctest(PropCheck)
  doctest(PropCheck.StateM)

  @moduletag capture_log: true

  @type my_stack(t) :: [t]
  @type tagged_stack(t) :: {:stack, [t]}

  test "find types in proper_gen.erl" do
    types = Kernel.Typespec.beam_types(:proper_gen)
    refute nil == types

    Logger.debug(fn -> inspect types end, pretty: true)
  end

  test "let/2 generates larger lists of bindings" do
    let_gen = let [
      m <- nat(),
      n <- nat(),
      o <- nat()
    ] do
      [m, n, o]
      :ok
    end

    assert capture_io(fn ->
      quickcheck(
        forall x <- let_gen do
          equals(:ok, x)
        end
      )
    end) =~ "Passed"
  end

  test "equals/2 outputs on error" do
    assert capture_io(fn ->
      quickcheck(
        forall x <- :not_ok do
          equals(:ok, x)
        end
      )
    end) =~ ":ok != :not_ok"
  end

  test "sample_shrink/2" do
    assert capture_io(fn ->
      assert :ok == sample_shrink(1)
    end) == "1\n"

    assert capture_io(fn ->
      assert :ok == sample_shrink([1, 2, 3])
    end) == "[1,2,3]\n"
  end

  describe "forall" do
    test "can use assertion in forall" do
      assert capture_io(fn ->
        quickcheck(
          forall _x <- :not_ok, [:verbose] do
          assert false
          end
        )
        end) =~ "Expected truthy, got false"
    end

    test "can use assertion in forall without output" do
      refute capture_io(fn ->
        quickcheck(
          forall _x <- :not_ok, [:quiet] do
          assert false
          end
        )
        end) =~ "Expected truthy, got false"
    end

    property "can use let-like assignment in forall" do
      forall [
        m <- integer(),
        n <- integer()
      ] do
        is_integer(m) and is_integer(n)
      end
    end

    test "syntax errors are reported" do
      assert_raise ArgumentError, fn ->
        Code.compile_string("""
          use PropCheck

          forall [n operator nat()], do: true
        """) =~ "Usage:"
      end

      assert_raise ArgumentError, fn ->
        Code.compile_string("""
          use PropCheck

          forall {n <- nat()}, do: true
        """) =~ "Usage:"
      end
    end
  end

  def recode_vars({:var, line, n}), do:
    {:var, line, n |> Atom.to_string |> String.upcase |> String.to_atom}
  def recode_vars({t, l, sub_t, expr}), do: {t, l, recode_vars(sub_t), recode_vars(expr)}
  def recode_vars([]), do: []
  def recode_vars([h | t]), do: [recode_vars(h) | recode_vars(t)]
  def recode_vars(what_ever), do: what_ever

  def get_type_in_abstract_form(module, type_name, arg_count \\ 0) do
    case abstract_code(module) do
      {:ok, abstract_code} ->
        # exported_types = for {:attribute, _, :export_type, types} <- abstract_code, do: types
        # exported_types = :lists.flatten(exported_types)

        for {:attribute, _, kind, {name, _, args}} = type <- abstract_code, kind
             in [:opaque, :type, :export_type] do
          if name == type_name and arg_count == length(args) do
            type
          else
            nil
          end
        end
    end
  end

  # Taken from Kernel.TypeSpec
  defp abstract_code(module) do
    case :beam_lib.chunks(abstract_code_beam(module), [:abstract_code]) do
      {:ok, {_, [{:abstract_code, {_raw_abstract_v1, abstract_code}}]}} ->
        {:ok, abstract_code}
      _ ->
        :error
    end
  end

  defp abstract_code_beam(module) when is_atom(module) do
    case :code.get_object_code(module) do
      {^module, beam, _filename} -> beam
      :error -> module
    end
  end

  defp abstract_code_beam(binary) when is_binary(binary) do
    binary
  end

end
