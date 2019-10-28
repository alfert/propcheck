defmodule PropCheck.DeriveGenerators do
  @moduledoc """
  Automatically derive generators from `@type`.

  https://hexdocs.pm/elixir/typespecs.html

  FIXME document restrictions
  * some types cannot be generated
  * opaque types could be a problem
  * type variables require that generator for the variables is passed in
  * if a type cannot be generated, required that it is passed in as an argument
  * %{required(k) => v} generates only one matching key-value pair right now
  * %{optional(k) => v} generates only one matching key-value pair right now
  """
  #
  # FIXME docs
  defmacro __using__(args) do
    only = Keyword.get(args, :only)

    case Keyword.get(args, :module) do
      nil ->
        quote do
          @propcheck_only unquote(only)
          @after_compile PropCheck.DeriveGenerators
        end

      module ->
        impl_generators(module, nil, only)
    end
  end

  defmacro __after_compile__(_env, bytecode) do
    {:ok, {module, _}} = :beam_lib.chunks(bytecode, [:abstract_code])
    impl_generators(module, bytecode, nil)
  end

  defp impl_generators(module, bytecode, only) do
    quote bind_quoted: [module: module, bytecode: bytecode, only: only] do
      only =
        try do
          Module.get_attribute(module, :propcheck_only)
        rescue
          _ ->
            only
        end

      {:ok, types} = Code.Typespec.fetch_types(bytecode || module)

      expanded =
        types
        |> Enum.filter(fn {key, _} -> key == :type end)
        |> Enum.filter(fn {_, {name, _, args}} ->
          is_nil(only) || {name, length(args)} in only
        end)
        |> Enum.map(&PropCheck.DeriveGenerators.Expand.expand/1)

      {all, generators} = Enum.unzip(expanded)

      any_generators =
        for generator_name when not is_nil(generator_name) <- all do
          quote do
            unquote(generator_name)()
          end
        end

      defs =
        quote do
          use PropCheck

          def all() do
            oneof(unquote(any_generators))
          end

          unquote_splicing(generators)
        end

      # XXX Debug
      # defs |> Macro.expand(__ENV__) |> Macro.to_string() |> IO.puts()

      module
      |> Module.concat(:Generate)
      |> Module.create(defs, Macro.Env.location(__ENV__))
    end
  end

end
