defmodule PropCheck do
    #
    # Test generation macros
    #

    defmacro forall({:in, _, [x, rawtype]}, [do: prop]) do
        quote do
            :proper.forall(unquote(rawtype), fn(unquote(x)) -> unquote(prop) end)
        end
    end
    
    defmacro implies(pre, prop) do
        quote do
            :proper.implies(unquote(pre), PropCheck.delay(unquote(prop)))
        end
    end

    defmacro whenfail(action, prop) do
        quote do
            :proper.whenfail(PropCheck.delay(unquote(action)), PropCheck.delay(unquote(prop)))
        end
    end

    defmacro trapexit(prop) do
        quote do
            :proper.trapexit(PropCheck.delay(unquote(prop)))
        end
    end

    defmacro timeout(limit, prop) do
        quote do
            :proper.timeout(unquote(limit), PropCheck.delay(unquote(prop)))
        end
    end


    # Generator macros
    defmacro force(x) do
        quote do
            unquote(x).()
        end
    end

    defmacro delay(x) do
        quote do
            fn() -> unquote(x) end
        end
    end

    defmacro lazy(x) do
        quote do
            :proper_types.lazy(PropCheck.delay(unquote(x)))
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
            :proper_types.add_constraint(unquote(rawtype),fn(unquote(x)) -> unquote(condition) end, unquote(strict))
        end
    end

    defmacro shrink(gen, alt_gens) do
        quote do
            :proper_types.shrinkwith(PropCheck.delay(unquote(gen)), PropCheck.delay(unquote(alt_gens)))
        end
    end

    defmacro letshrink({:=, _, [x, rawtype]},[do: gen]) do
        quote do
            :proper_types.bind(unquote(rawtype), fn(unquote(x)) -> unquote(gen) end, true)
        end
    end

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
      hash = :crypto.hash(:binary.encode_unsigned(time2us(time)))
      us2time(:binary.decode_unsigned(hash))
    end

    defp time2us({ms, s, us}), do: ms*tera + s*mega + us
    defp us2time(n) do
      {rem(div(n, tera), mega), rem(div(n, mega), mega), rem(n, mega)}
    end


end
