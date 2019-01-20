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
        exists input <- params do      # some input exists that fullfills the property.
            uv = sut.run(input)        # Do so by running SUT with input
            maximize(uv)               # and maximize its utility value
            uv < threshold             # up to some threshold, the property condition.
        end
      end

  Most of the documentation is taken directly from PropEr.

  """

  @in_ops [:<-, :in]

  @doc """
  The `exists` macro uses the targeted PBT component of PropEr to try
  to find one instance of `xs` that makes the `prop` return `true`. If such a `xs`
  is found, the property passes. Note that there is no counterexample if no
  such `xs` could be found.
  """
  defmacro exists({:<-, _, [var, rawtype]}, do: prop_body) do
    quote do
        :proper.exists(unquote(rawtype),
            fn(unquote(var)) -> unquote(prop_body) end, true)
    end
  end

  @doc """
  The `not_exists` macro uses the targeted PBT component of PropEr to try
  to find one instance of `xs` that makes the `prop` return `false`. If such a `xs`
  is found the property passes. Note that there is no counterexample if no
  such `xs` could be found.
  """
  defmacro not_exists({op, _, [var, rawtype]}, do: prop_body) when op in @in_ops do
    quote do
      :proper.exists(unquote(rawtype), fn unquote(var) -> unquote(prop_body) end, false)
    end
  end

  @doc """
  The `forall_targeted` macros uses the targeted PBT component of PropEr to try
  that all instances of `xs` fullfill porperty `prop`. In contrast to `exists`, often
  the property here is negated.
  """
  defmacro forall_targeted({op, _, [var, rawtype]}, do: prop_body) when op in @in_ops do
    quote do
      :proper.exists(unquote(rawtype), fn unquote(var) -> not (unquote(prop_body)) end, true)
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
  This macro tells the search strategy to minize the value `fitness` and
  is equivalent to `maximaize(-fitness)`.
  """
  defmacro minimize(fitness) do
    quote do
      :proper_target.update_target_uvs(- unquote(fitness), :inf)
    end
  end

  @doc """
  This uses the neighborhood function `nf` instead of PropEr's
  constructed neighborhood function for this generator. The neighborhood
  function `fun` should be of type
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
  `matcher` function. The matcher should be of type `proper_gen_next:matcher()`
  """
  defmacro user_matcher(generator, matcher) do
    quote do
      :proper_gen_next.set_matcher(unquote(generator), unquote(matcher))
    end
  end

  # -define(TARGET(TMap), proper_target:targeted(make_ref(), TMap)).
  # -define(STRATEGY(Strat, Prop), ?SETUP(fun (Opts) ->
  #       proper_target:use_strategy(Strat, Opts),
  #       fun proper_target:cleanup_strategy/0
  #   end, Prop)).

  @doc """
  For backward compatibility with the scientific papers.
  """
  defmacro target(tmap) do
    quote do
      :proper_target.targeted(make_ref(), unquote(tmap))
    end
  end

  # -define(SETUP(SetupFun,Prop), proper:setup(SetupFun,Prop))
  @doc """
  For backward compatibility with the scientific papers.
  """
  defmacro setup(setup_fun, prop) do
    quote do
      :proper.setup(unquote(setup_fun), unquote(prop))
    end
  end

  @doc """
  For backward compatibility with the scientific papers.
  """
  defmacro strategy(strat, prop) do
    quote do
      unquote(__MODULE__).setup(fn opts ->
        :proper_target.use_strategy(unquote(strat), opts)
        &:proper_target.cleanup_strategy/0
      end, unquote(prop))
    end
  end

  # -define(FORALL_SA(X, RawType, Prop),
  #   ?STRATEGY(proper_sa, proper:forall(RawType,fun(X) -> Prop end))).
  @doc """
  For backward compatibility with the scientific papers.
  """
  defmacro forall_sa({:<-, _, [var, rawtype]}, do: prop_body) do
    quote do
      strategy(:proper_sa,
        :proper.forall(unquote(rawtype),
          fn(unquote(var)) -> unquote(prop_body) end))
    end
  end

end
