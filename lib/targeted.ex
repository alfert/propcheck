defmodule PropCheck.TargetedPBT do
  @moduledoc """
  This module defines the top-level behaviour for targeted property-based testing (TPBT).
  Using TPBT the input generation is no longer random, but guided by a search strategy to
  increase the probability of finding failing input. For this to work the user has to specify
  a search strategy and also needs to extract utility-values from the system under test that
  the search strategy then tries to maximize.

  To use TPBT the test specification macros `forall_targeted`, `exists`, and `not_exists` are used.
  The typical structure for a targeted property looks as follows:

      property prop_target do          # Try to check that
        exists input <- params do      # some input exists that fulfills the property.
            uv = sut.run(input)        # Do so by running SUT with input
            maximize(uv)               # and maximize its utility value
            uv < threshold             # up to some threshold, the property condition.
        end
      end

  ## Some thoughts on strategies how to use targeted properties

  Targeted PBT is a rather new technology and really fascinating. But when should you to use it and when are
  the classical technologies more suitable? Here are some thoughts on that topic based on the
  limited experience we currently have.

  If you want to test interesting parts of your algorithms or data structures, you would typically invest
  into more elaborated generators. If you are working on binary trees and you need more lefty trees, then a new
  generator is required that somehow generates trees of that particular shape. The big advantage here is that
  you can use all of the standard functions and macros, in particular for collecting statistics about the quality
  of the generated data (e.g. by `PropCheck.collect/2` and its friends).

  Another approach would be to use targeted properties
  as shown in `targeted_tree_test.exs`: You use a rather simple data generator and define a measuring function
  on the data to express the "leftiness" of the tree. Equiped with that, a target property searches automatically
  for data the maximizes (or minimizes) the measuring function (often called utility value or function). Not
  inventing a clever data generators comes with a price - there is no free lunch...
  * You need some _relevant_ property of your generated data which you can measure, i.e. you need a function
    from your data to the real numbers. This is not always possible.
  * Searching for an optimum takes more time than simply generating random data: the run-time of the properties
    increases.
  * Data collecting functions and macros such as `PropCheck.collect/2` are currently not available. This
    it the reason why in `targeted_tree_test.exs` we use print-outs to show and verify the generated data.
  * Counter examples and shrinking are not available
  * The current implementation in PropEr does not work well together with recursive data generators, which
    renders the approach unusable for state-based PBT.

  But, of course, you gain also something. You can use rather straight data generators and let the searching
  algorithm find the interesting parts with respect to the measuring function.

  In `level_tpbt_test.exs` a very different approach is used. Here the basic idea is to verify that a data
  structure (here: a maze in a computer game) has a proper structure (here: there exists at least one valid
  path from the entrance to the exit of the maze). The function to minimize is the distance from the end of
  the path to the exit position. The searching algorithm then optimizes the path length for a minimal
  distance until the exit is found. For more complex mazes, it is required to adopt the amount of `search_steps`
  and the `neighbor_hood` function to find the exit. They takes over the role `numtests` and `resize` to
  enlarge or refit the generated data for the next search step.

  You can combine approaches by using a classical generator for e.g. generating a new maze, and then use
  inside a targeted property to find a path to the maze's exit. This would be roughly like this:

      forall maze <- maze_generator() do
        exists p <- path_generator() do
          pos = Maze.follow_path(maze, maze.entry_pos, p)
          uv = distance(pos, maze.exit_pos)
          minimize(uv)
          pos == maze.exit_pos
        end
      end

  ## How the targeted properties relate

  The targeted macros `forall_targeted`, `exists` and `not_exists` are related to each other.
  The universal laws of quantors from first-order logic apply here as well (cf.
  [provable entities in first-order logic](https://en.wikipedia.org/wiki/First-order_logic#Provable_identities))
  and explain why some conditions in the test examples are constructed the way they are.

  In the following, we use the variable `x`, the generator `x_gen()` and a boolean predicate `p()`. The
  term `<==>` means that the expression on both sides are equivalent.

      forall_targeted x <- x_gen(), do: p(x)
         <==> not_exists x <- x_gen(), do: not(p(x))

      exists x <- x_gen(), do: p(x)
         <==> forall_targeted x <- x_gen(), do: not(p(x))
              |> fails()

      not_exists x <- x_gen(), do: p(x)
         <==> forall_targeted x <- x_gen(), do: not(p(x))

  ## Options

  For targeted properties exists a new option:
  * `{:search_steps, non_negative_number}` <br>
    takes an integer defining how many search steps the searching algorithm takes.
    Its default value is `1_000`.  The effect of `search_steps` is similar to `num_tests` for
    ordinary properties. `num_tests` has no effect on the search strategy. This helps when you
    combine a regular property with search strategy, e.g. generating a configuration parameter
    and search for specific properties to hold depending on that parameter.

  Some of the documentation is taken directly from PropEr.

  """

  @in_ops [:<-, :in]

  @doc """
  The `exists` macro uses the targeted PBT component of PropEr to try
  to find one instance of `xs` that makes the `prop` return `true`.

  If such a `xs`
  is found, the property passes. Note that there is no counterexample if no
  such `xs` could be found.
  """
  defmacro exists({:<-, _, [var, rawtype]}, do: prop_body) do
    quote do
      :proper.exists(unquote(rawtype), fn unquote(var) -> unquote(prop_body) end, false)
    end
  end

  @doc """
  The `not_exists` macro uses the targeted PBT component of PropEr to try
  to find one instance of `xs` that makes the `prop` return `false`.

  If such a `xs`
  is found the property passes. Note that there is no counterexample if no
  such `xs` could be found.
  """
  defmacro not_exists({op, _, [var, rawtype]}, do: prop_body) when op in @in_ops do
    quote do
      :proper.exists(unquote(rawtype), fn unquote(var) -> unquote(prop_body) end, true)
    end
  end

  @doc """
  The `forall_targeted` macros uses the targeted PBT component of PropEr to try
  that all instances of `xs` fulfill property `prop`.

  In contrast to `exists`, often the property here is negated.
  """
  defmacro forall_targeted({op, _, [var, rawtype]}, do: prop_body) when op in @in_ops do
    quote do
      :proper.exists(unquote(rawtype), fn unquote(var) -> not unquote(prop_body) end, true)
    end
  end

  @doc """
  This macro tells the search strategy to maximize the value `fitness`.
  """
  defmacro maximize(fitness) do
    quote do
      :proper_target.update_target_uvs(unquote(fitness), :inf)
    end
  end

  @doc """
  This macro tells the search strategy to minimize the value `fitness` and
  is equivalent to `maximize(-fitness)`.
  """
  defmacro minimize(fitness) do
    quote do
      :proper_target.update_target_uvs(-unquote(fitness), :inf)
    end
  end

  @doc """
  This uses the neighborhood function `nf` instead of PropEr's
  constructed neighborhood function for this generator.

  The neighborhood function `nf` should be of type
  `fun(any(), {Depth :: number(), Temperature::float()} -> any()`
  """
  defmacro user_nf(generator, nf) do
    quote do
      :proper_gen_next.set_user_nf(unquote(generator), unquote(nf))
    end
  end

  # -define(USERMATCHER(Type, Matcher), proper_gen_next:set_matcher(Type, Matcher)).
  @doc """
  This overwrites the structural matching of PropEr for the generator with the user provided
  `matcher` function.

  The `matcher` should be of type `:proper_gen_next.matcher()`
  """
  defmacro user_matcher(generator, matcher) do
    quote do
      :proper_gen_next.set_matcher(unquote(generator), unquote(matcher))
    end
  end

  # -define(TARGET(TMap), proper_target:targeted(make_ref(), TMap)).

  # For backward compatibility with the scientific papers.
  @doc false
  defmacro target(tmap) do
    quote do
      tmap_val = unquote(tmap)
      Logger.debug(fn -> "target: tmap = #{inspect(tmap_val)}" end)
      :proper_target.targeted(make_ref(), tmap_val)
    end
  end

  # For backward compatibility with the scientific papers.
  # -define(STRATEGY(Strat, Prop), ?SETUP(fun (Opts) ->
  #       proper_target:use_strategy(Strat, Opts),
  #       fun proper_target:cleanup_strategy/0
  #   end, Prop)).
  @doc false
  defmacro strategy(strat, prop) do
    quote do
      PropCheck.property_setup(
        fn opts ->
          :proper_target.use_strategy(unquote(strat), opts)
          &:proper_target.cleanup_strategy/0
        end,
        unquote(prop)
      )
    end
  end

  # -define(FORALL_SA(X, RawType, Prop),
  #   ?STRATEGY(proper_sa, proper:forall(RawType,fun(X) -> Prop end))).
  # For backward compatibility with the scientific papers.
  @doc false
  defmacro forall_sa({:<-, _, [var, rawtype]}, do: prop_body) do
    quote do
      strategy(
        :proper_sa,
        forall unquote(var) <- unquote(rawtype) do
          unquote(prop_body)
        end
      )

      # :proper.forall(unquote(rawtype),
      #   fn(unquote(var)) -> unquote(prop_body) end))
    end
  end
end
