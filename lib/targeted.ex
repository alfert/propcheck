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
        exists input <- params do       # some input exists that fullfills the property.
            uv = sut.run(input)        # Do so by running SUT with Input
            maximize(uv)               # and maximize its Utility Value
            uv < threshold             # up to some Threshold.
        end
      end

  """

  #  -define(EXISTS(X,RawType,Prop), proper:exists(RawType, fun(X) -> Prop end, false)).
  # -define(NOT_EXISTS(X,RawType,Prop), proper:exists(RawType, fun(X) -> Prop end, true)).
  # -define(FORALL_TARGETED(X, RawType, Prop),
  #     proper:exists(RawType, fun(X) -> not Prop end, true)).
  @in_ops [:<-, :in]

  @doc """
  The `exists` macro uses the targeted PBT component of PropEr to try
  to find one instance of `xs` that makes the `prop` true. If such a `xs`
  is found the property passes. Note that there is no counterexample if no
  such `xs` could be found.
  """
  # defmacro exists({op, _, [var, rawtype]}, do: prop_body) when op in @in_ops do
  #   quote do
  #     :proper.exists(unquote(rawtype), fn unquote(var) -> unquote(prop_body) end, true)
  #   end
  # end

  defmacro exists({:<-, _, [var, rawtype]}, do: prop_body) do
    quote do
        :proper.exists(unquote(rawtype),
            fn(unquote(var)) -> unquote(prop_body) end, true)
    end
  end


  defmacro not_exists({op, _, [var, rawtype]}, do: prop_body) when op in @in_ops do
    quote do
      :proper.exists(unquote(rawtype), fn unquote(var) -> unquote(prop_body) end, false)
    end
  end

  defmacro forall_targeted({op, _, [var, rawtype]}, do: prop_body) when op in @in_ops do
    quote do
      :proper.exists(unquote(rawtype), fn unquote(var) -> not unquote(prop_body) end, true)
    end
  end

  # -define(MAXIMIZE(Fitness), proper_target:update_target_uvs(Fitness, inf)).
  # -define(MINIMIZE(Fitness), ?MAXIMIZE(-Fitness)).
  # -define(USERNF(Type, NF), proper_gen_next:set_user_nf(Type, NF)).
  # -define(USERMATCHER(Type, Matcher), proper_gen_next:set_matcher(Type, Matcher)).

  defmacro maximize(fitness) do
    quote do
      :proper_target.update_target_uvs(unquote(fitness), :inf)
    end
  end
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
  defmacro user_nf(type, nf) do
    quote do
      :proper_gen_next.set_user_nf(unquote(type), unquote(nf))
    end
  end

  # -define(TARGET(TMap), proper_target:targeted(make_ref(), TMap)).
  # -define(STRATEGY(Strat, Prop), ?SETUP(fun (Opts) ->
  #       proper_target:use_strategy(Strat, Opts),
  #       fun proper_target:cleanup_strategy/0
  #   end, Prop)).

  defmacro target(tmap) do
    quote do
      :proper_target.targeted(make_ref(), unquote(tmap))
    end
  end

  # -define(SETUP(SetupFun,Prop), proper:setup(SetupFun,Prop))
  defmacro setup(setup_fun, prop) do
    quote do
      :proper.setup(unquote(setup_fun), unquote(prop))
    end
  end

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
  defmacro forall_sa({:<-, _, [var, rawtype]}, do: prop_body) do
    quote do
      strategy(:proper_sa,
        :proper.forall(unquote(rawtype),
          fn(unquote(var)) -> unquote(prop_body) end))
    end
  end

end
