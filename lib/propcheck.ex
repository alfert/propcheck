defmodule PropCheck do
    @moduledoc """
    Provides the macros and functions for property based testing
    using `proper` as base implementation. `PropCheck` supports many
    features of `proper`, but the automated generation of test data
    generators is only partially supported due to internal features of
    `proper` focussing of Erlang only.

    ## Using `PropCheck`
    To use `PropCheck`, you need to add `use PropCheck.Properties` to your
    Elixir files. This gives you access to the functions and macros
    defined here as well as to the `property` macros. In most examples shown
    here, we directly use the `quickcheck` function, but typically you
    use the `property` macro instead to define test cases for `ExUnit`.

    ## Acknowldgement
    Very much of the documentation is immediately taken from the
    `proper` API documentation.
    """

    @doc """
    A property that should hold for all values generated.

        iex> use PropCheck.Properties
        iex> quickcheck(
        ...> forall n <- nat do
        ...>   n >= 0
        ...> end)
        true

    If you need more than one generator, collect the generator names
    and the generators definitions in tuples or lists, respectively:

        iex> use PropCheck.Properties
        iex> quickcheck(
        ...> forall [n, l] <- [nat, list(nat)] do
        ...>   n * Enum.sum(l) >= 0
        ...> end
        ...>)
        true
    """
    @in_ops [:<-, :in]
    defmacro forall({op, _, [x, rawtype]}, do: prop) when op in @in_ops do
        quote do
            :proper.forall(unquote(rawtype), fn(unquote(x)) -> unquote(prop) end)
        end
    end
    defmacro forall(binding, property), do: syntax_error("var <- generator, do: prop")

    @doc """
    This wrapper only makes sense when in the scope of at least one
    `forall`. The `precondition` field must be a boolean expression or a
    statement block that returns a boolean. If the precondition evaluates to
    `false` for the variable instances produced in the enclosing `forall`
    wrappers, the test case is rejected (it doesn't count as a failing test
    case), and `PropCheck` starts over with a new random test case. Also, in
    verbose mode, an `x` is printed on screen.

        iex> use PropCheck.Properties
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
    failure, instead of crashing. `trap_exit` cannot contain any more
    wrappers.

        iex> use PropCheck.Properties
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
    than `time_limit` milliseconds to return. The purpose of this wrapper is
    to test code that may hang if something goes wrong. `timeout` cannot
    contain any more wrappers.

        iex> use PropCheck.Properties
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

    defmacro lazy(x) do
      quote do
        :proper_types.lazy(delay(unquote(x)))
      end
    end

    defmacro delay(x) do
      quote do
        fn() -> unquote(x) end
      end
    end

    defmacro sized(size_arg, gen) do
        quote do
            :proper_types.sized(fn(unquote(size_arg)) -> unquote(gen) end)
        end
    end

    defmacro let({:"=", _, [x, rawtype]},[{:do, gen}]) do
        quote do
            :proper_types.bind(unquote(rawtype), fn(unquote(x)) -> unquote(gen) end, false)
        end
    end

    defmacro let({:"=", _, [x, rawtype]}, opts) do
        unless opts[:when], do: throw(:badarg)
        condition = opts[:when]
        strict = Keyword.get(opts, :strict, true)
        quote do
            :proper_types.add_constraint(unquote(rawtype),
              fn(unquote(x)) -> unquote(condition) end, unquote(strict))
        end
    end

    defmacro shrink(gen, alt_gens) do
        quote do
            :proper_types.shrinkwith(delay(unquote(gen)), delay(unquote(alt_gens)))
        end
    end

    defmacro letshrink({:=, _, [x, rawtype]},[do: gen]) do
        quote do
            :proper_types.bind(unquote(rawtype), fn(unquote(x)) -> unquote(gen) end, true)
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
