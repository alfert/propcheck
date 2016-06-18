defmodule PropCheck do
    @moduledoc """
    Provides the macros and functions for property based testing
    using `proper` as base implementation. `PropCheck` supports many
    features of `proper`, but the automated generation of test data
    generators is only partially supported due to internal features of
    `proper` focussing of Erlang only.

    ## Using PropCheck
    To use `PropCheck`, you need to add `use PropCheck` to your
    Elixir files. This gives you access to the functions and macros
    defined here as well as to the `property` macros. In most examples shown
    here, we directly use the `quickcheck` function, but typically you
    use the `property` macro instead to define test cases for `ExUnit`.

    Also availables are the value generators which are imported directly
    from `PropCheck.BasicTypes`.

    ## Acknowldgements
    Very much of the documentation is immediately taken from the
    `proper` API documentation.
    """
    defmacro __using__(_) do
        quote do
            import PropCheck
            import PropCheck.Properties
            # import :proper_types, except: [lazy: 1, to_binary: 1, function: 2]
            import PropCheck.BasicTypes
        end
    end


    @doc """
    A property that should hold for all values generated.

        iex> use PropCheck
        iex> quickcheck(
        ...> forall n <- nat do
        ...>   n >= 0
        ...> end)
        true

    If you need more than one generator, collect the generator names
    and the generators definitions in tuples or lists, respectively:

        iex> use PropCheck
        iex> quickcheck(
        ...> forall [n, l] <- [nat, list(nat)] do
        ...>   n * Enum.sum(l) >= 0
        ...> end
        ...>)
        true
    """
    @in_ops [:<-, :in]
    defmacro forall({op, _, [var, rawtype]}, do: prop) when op in @in_ops do
        quote do
            :proper.forall(unquote(rawtype), fn(unquote(var)) -> unquote(prop) end)
        end
    end
    defmacro forall(binding, property), do: syntax_error("var <- generator, do: prop")

    @doc """
    A property that is only tested if a condition is true.

    This wrapper only makes sense when in the scope of at least one
    `forall`. The `precondition` field must be a boolean expression or a
    statement block that returns a boolean. If the precondition evaluates to
    `false` for the variable instances produced in the enclosing `forall`
    wrappers, the test case is rejected (it doesn't count as a failing test
    case), and `PropCheck` starts over with a new random test case. Also, in
    verbose mode, an `x` is printed on screen.

        iex> use PropCheck
        iex> require Integer
        iex> quickcheck(
        ...> forall n <- nat do
        ...>    implies rem(n,2) == 0, do: Integer.is_even n
        ...> end
        ...>)
        true
    """
    defmacro implies(precondition, do: property) do
        quote do
            :proper.implies(unquote(precondition), delay(unquote(property)))
        end
    end

    @doc """
    Exectute an action, if the property fails.

    The `action` field should contain an expression or statement block
    that produces some side-effect (e.g. prints something to the screen).
    In case this test fails, `action` will be executed. Note that the output
    of such actions is not affected by the verbosity setting of the main
    application.
    """
    defmacro when_fail(action, prop) do
        quote do
            :proper.whenfail(delay(unquote(action)), delay(unquote(prop)))
        end
    end

    @doc """
    If the code inside `prop` spawns and links to a process that dies
    abnormally, PropEr will catch the exit signal and treat it as a test
    failure, instead of crashing.

    `trap_exit` cannot contain any more wrappers.

        iex> use PropCheck
        iex> quickcheck(
        ...>   trap_exit(forall n <- nat do
        ...>     # this must fail
        ...>     pid = spawn_link(fn() -> n / 0 end)
        ...>     # wait for arrivial of the dieing linked process signal
        ...>     :timer.sleep(50)
        ...>     true #
        ...>   end)
        ...> )
        false
    """
    defmacro trap_exit(do: prop) do
      quote do
        :proper.trapexit(delay(unquote(prop)))
      end
    end

    defmacro trap_exit(prop) do
        quote do
            :proper.trapexit(delay(unquote(prop)))
        end
    end

    @doc """
    Signifies that `prop` should be considered failing if it takes more
    than `time_limit` milliseconds to return.

    The purpose of this wrapper is
    to test code that may hang if something goes wrong. `timeout` cannot
    contain any more wrappers.

        iex> use PropCheck
        iex> quickcheck(
        ...>   timeout(100, forall n <- nat do
        ...>     :ok == :timer.sleep(n*100)
        ...>   end)
        ...> )
        false

    """
    defmacro timeout(time_limit, prop) do
        quote do
            :proper.timeout(unquote(time_limit), delay(unquote(prop)))
        end
    end

    @doc """
    Mostly internally used macro to create a lazy value for `proper`.

    The parameter `delayed_value` needs to be an already delayed value.
    """
    defmacro lazy(delayed_value) do
      quote do
        :proper_types.lazy(delay(unquote(delayed_value)))
      end
    end

    @doc """
    Delays the evaluation of `expr`.

    Required for defining recursive generators and similar situations.
    """
    defmacro delay(expr) do
      quote do
        fn() -> unquote(expr) end
      end
    end

    @doc """
    Changes the maximum size of the generated instances.

    `sized` creates a new type, whose instances are produced by replacing all
    appearances of the `size` parameter inside the statement block
    `generator` with the value of the `size` parameter. It's OK for the
    `generator` to return a type - in that case, an instance of the inner
    type is generated recursively.


    """
    defmacro sized(size, generator) do
        quote do
            :proper_types.sized(fn(unquote(size)) -> unquote(generator) end)
        end
    end

    @doc """
    Binds a generator to a name for use in another generator.

    The `binding` has the generator syntax `x <- type`.
    To produce an instance of this type, all appearances of the variables
    in `x` are replaced inside `generator` by their corresponding values in a
    randomly generated instance of `type`. It's OK for the `gen` part to
    evaluate to a type - in that case, an instance of the inner type is
    generated recursively.

        iex> use PropCheck
        iex> even = let n <- nat do
        ...>  n * 2
        ...> end
        iex> quickcheck(
        ...>   forall n <- even do
        ...>     rem(n, 2) == 0
        ...>   end)
        true

    If you require more than one type, put the pairs of variable and type
    into a list as shown in the example below.

        iex> use PropCheck
        iex> even_factor = let [n <- nat, m <- nat] do
        ...>  n * m * 2
        ...> end
        iex> quickcheck(
        ...>   forall n <- even_factor do
        ...>     rem(n, 2) == 0
        ...>   end)
        true

    """
    defmacro let({:<-, _, [var, rawtype]}, generator) do
        [{:do, gen}] = generator
        quote do
            :proper_types.bind(unquote(rawtype),
                fn(unquote(var)) -> unquote(gen) end, false)
        end
    end

    defmacro let([{:<-, _, _} | rest] = bindings, [{:do, gen}]) do
        bound = let_bind(bindings) |> Enum.reverse
        vars = bound |> Enum.map(&(elem(&1, 0)))
        raw_types = bound |> Enum.map(&(elem(&1, 1)))
        quote do
          :proper_types.bind(unquote(raw_types),
            fn(unquote(vars)) -> unquote(gen) end, false)
        end
    end
    defp let_bind({:<-, _, [var, rawtype]} = bind), do: {var, rawtype}
    defp let_bind([{:<-, _, [var, rawtype]}]) do
      {var, rawtype}
    end
    defp let_bind([{:<-, _, [var, rawtype]} | rest]) do
      [{var, rawtype}, let_bind(rest)]
    end

    @doc """
    This produces a specialization of a generator, encoded as
    a binding of form `x <- type` (as in the let macro).

    The specialization of members of `type` that satisfy the
    constraint `condition` - that is,
    those members for which the function `fn(x) -> condition end` returns
    `true`. If the constraint is very strict - that is, only a small
    percentage of instances of `type` pass the test - it will take a lot of
    tries for the instance generation subsystem to randomly produce a valid
    instance. This will result in slower testing, and testing may even be
    stopped short, in case the `constraint_tries` limit is reached (see the
    "Options" section in the documentation of the {@link proper} module).

    If this is the case, it would be more appropriate to generate valid instances
    of the specialized type using the `let` macro. Also make sure that even
    small instances can satisfy the constraint, since PropEr will only try
    small instances at the start of testing. If this is not possible, you can
    instruct PropEr to start at a larger size, by supplying a suitable value
    for the `start_size` option (see the "Options" section in the
    documentation of the {@link proper} module).

        iex> use PropCheck
        iex> even = such_that n <- nat, when: rem(n, 2) == 0
        iex> quickcheck(
        ...>   forall n <- even do
        ...>     rem(n, 2) == 0
        ...>   end)
        true

    """
    defmacro such_that({:<-, _, [var, rawtype]} = binding, condition)  do
        unless condition[:when], do: throw(:badarg)
        cond_block = condition[:when]
        strict = Keyword.get(condition, :strict, true)
        quote do
            :proper_types.add_constraint(unquote(rawtype),
              fn(unquote(var)) -> unquote(cond_block) end, unquote(strict))
        end
    end

    @doc """
    Equivalent to the `such_that` macro, but the constraint `condition`
    is considered non-strict: if the `constraint_tries` limit is reached, the
    generator will just return an instance of `type` instead of failing,
    even if that instance doesn't satisfy the constraint.

        iex> use PropCheck
        iex> even = such_that_maybe n <- nat, when: rem(n, 2) == 0
        iex> quickcheck(
        ...>   forall n <- even do
        ...>     rem(n, 2) == 0
        ...>   end)
        true

    """
    defmacro such_that_maybe({:<-, _, [x, rawtype]} = binding, condition)  do
        unless condition[:when], do: throw(:badarg)
        cond_block = condition[:when]
        strict = Keyword.get(condition, :strict, false)
        quote do
            :proper_types.add_constraint(unquote(rawtype),
              fn(unquote(x)) -> unquote(cond_block) end, unquote(strict))
        end
    end

    @doc """
    Defines the shrinking of a generator.

    `shrink` creates a type whose instances are generated by evaluating the
    statement block `generator` (this may evaluate to a type, which will
    then be generated recursively). If an instance of such a type is to be
    shrunk, the generators in `alt_gens` are first run to produce
    hopefully simpler instances of the type. Thus, the generators in the
    second argument should be simpler than the default. The simplest ones
    should be at the front of the list, since those are the generators
    preferred by the shrinking subsystem. Like the main `generator`, the
    alternatives may also evaluate to a type, which is generated recursively.

            iex> use PropCheck
            iex> quickcheck(
            ...>   forall n <- shrink(pos_integer, [0]) do
            ...>     rem(n, 2) == 0
            ...>   end)
            false

    """
    defmacro shrink(generator, alt_gens) do
        quote do
            :proper_types.shrinkwith(delay(unquote(generator)),
                delay(unquote(alt_gens)))
        end
    end

    @doc """
    A combination of a `let` and a `shrink` macro.

    Instances
    are generated by applying a randomly generated list of values inside
    `generator` (just like a `let`, with the added constraint that the
    variables and types must be provided in a list - alternatively,
    `list_of_types` may be a list or vector type). When shrinking instances
    of such a type, the sub-instances that were combined to produce it are
    first tried in place of the failing instance.

    One possible use is shown in the `tree` example. A recursive
    tree generator with an efficient shrinking: pick each of the
    subtrees in place of the tree that fails the property. `l` and `r`
    are assigned smaller versions of the tree thus achieving a better
    (or more appropriate) shrinking.

        def tree(g), do: sized(s, tree(s, g))
        def tree(0, _), do: :leaf
        def tree(s, g), do:
        	frequency [
        		{1, tree(0, g)},
        		{9, let_shrink([
    						l <- tree(div(s, 2), g),
    						r <- tree(div(s, 2), g)
    					]) do
        				{:node, g, l, r}
        			end
        			}
        	]

    """
    defmacro let_shrink({:<-, _, [var, rawtype]}, [do: gen]) do
        quote do
            :proper_types.bind(unquote(rawtype),
                fn(unquote(var)) -> unquote(gen) end, true)
        end
    end
    defmacro let_shrink([{:<-, _, _} | rest] = bindings, [do: gen]) do
        bound = let_bind(bindings) |> Enum.reverse
        vars = bound |> Enum.map(&(elem(&1, 0)))
        raw_types = bound |> Enum.map(&(elem(&1, 1)))
        quote do
          :proper_types.bind(unquote(raw_types),
            fn(unquote(vars)) -> unquote(gen) end, true)
      end
  end

    @doc "Runs all properties of a module and return the list of succeeded and failed properties."
    def run(target), do: run(target, [report: true, output: true])
    def run(target, opts) do
       PropCheck.Result.start_link
       on_output =
         fn(msg, args) ->
            PropCheck.Result.message(msg, args)
            opts[:output] && :io.format(msg, args)
            :ok
         end
       module(target, [:long_result, {:on_output, on_output}])
       {tests, errors} = PropCheck.Result.status
       passes = length(tests)
       failures = length(errors)
       PropCheck.Result.stop
       if opts[:report] do
         IO.puts "#{inspect passes} properties, #{inspect failures} failures."
       end
       {tests, errors}
    end

    def produce(gen, seed \\ :undefined) do
      :proper_gen.pick(gen, 10, fork_seed(seed))
    end

    defmacro is_property(x) do
      quote do: is_tuple(unquote(x)) and elem(unquote(x), 0) == :"$type"
    end

    @doc """
    Generates an `ExUnit` testcase for each property of the given module.
    Reporting of failures is then done via the usual `ExUnit` mechanism.
    """
    defmacro prop_test(mod) do
      props = mod |> Macro.expand(__CALLER__) |> extract_props
      props |> Enum.map(fn {f, 0} ->
        prop_name = "#{f}"
        quote do
          test unquote(prop_name) do
            exec_property(unquote(mod), unquote(f))
          end
        end
      end)
    end

    defmacro property_test(p, do: body) when is_binary(p)  do
      prop = p |> Macro.expand(__CALLER__)
      mod = __CALLER__.module
      f = "prop_#{prop}" |> String.to_atom
      quote do
        test unquote(prop) do
          exec_property(unquote(mod), unquote(f))
        end
        property unquote(prop) do
          unquote(body)
        end
      end
    end

    @doc "Runs the property as part of an `ExUnit` test case."
    def exec_property(m, f ) do
      p = apply(m, f, [])
      should_fail = is_tuple(p) and elem(p, 0) == :fails
      case PropCheck.quickcheck(p, [:long_result]) do
        true when not should_fail -> true
        true when should_fail ->
          raise ExUnit.AssertionError, [
            message:
              "Property #{inspect m}.#{f} should fail, but succeeded for all test data :-(",
            expr: nil]
        counter_example when should_fail -> true
        counter_example ->
          raise ExUnit.AssertionError, [
            message: """
            Property #{inspect m}.#{f} failed. Counter-Example is:
            #{inspect counter_example, pretty: true}
            """,
                expr: nil]
      end
    end

    @doc "Extracs all properties of module."
    @spec extract_props(atom) :: [{atom, arity}]
    def extract_props(mod) do
      apply(mod,:__info__, [:functions])
        |> Stream.filter(
          fn {f, 0} -> f |> Atom.to_string |> String.starts_with?( "prop_")
                  _ -> false end)
    end


    # Delegates

    defdelegate [quickcheck(outer_test), quickcheck(outer_test, user_opts),
                 counterexample(outer_test), counterexample(outer_test, user_opts),
                 check(outer_test, cexm), check(outer_test, cexm, user_opts),
                 module(mod), module(mod, user_opts), check_spec(mfa), check_spec(mfa, user_opts),
                 check_specs(mod), check_specs(mod, user_opts),
                 numtests(n, test), fails(test), on_output(print, test), conjunction(sub_props),
                 collect(category, test), collect(printer, category, test),
                 aggregate(sample, test), aggregate(printer, sample, test),
                 classify(count, sample, test), measure(title, sample, test),
                 with_title(title), equals(a,b)], to: :proper

    # Helper functions
    defmacrop kilo, do: 1_000
    defmacrop mega, do: 1_000_0000
    defmacrop tera, do: 1_000_0000_000_0000
    defp fork_seed(:undefined = u), do: u
    defp fork_seed(time) do
      hash = :crypto.hash(:md5, :binary.encode_unsigned(time2us(time)))
      us2time(:binary.decode_unsigned(hash))
    end

    defp time2us({ms, s, us}), do: ms*tera + s*mega + us
    defp us2time(n) do
      {rem(div(n, tera), mega), rem(div(n, mega), mega), rem(n, mega)}
    end

    defp syntax_error(err), do: raise(ArgumentError, "Usage: " <> err)


end
