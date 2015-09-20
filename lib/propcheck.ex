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

    defmacro when_fail(action, prop) do
        quote do
            :proper.whenfail(PropCheck.delay(unquote(action)), PropCheck.delay(unquote(prop)))
        end
    end

    defmacro trap_exit(do: prop) do
      quote do
        :proper.trapexit(PropCheck.delay(unquote(prop)))
      end
    end

    defmacro trap_exit(prop) do
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
    defmacro prop_test(mod) when is_atom(mod) do
      props = mod |> Macro.expand(__CALLER__) |> extract_props
      props |> Enum.map fn {f, 0} ->
        prop_name = "#{f}"
        quote do
          test unquote(prop_name) do
            exec_property(unquote(mod), unquote(f))
          end
        end
      end
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
      case PropCheck.quickcheck(p, [:long_result]) do
        true -> true
        counter_example ->
          raise ExUnit.AssertionError, [
            message: "Property #{inspect m}.#{f} failed. Counter-Example is: \n#{inspect counter_example}",
                expr: nil]
      end
    end

    @doc "Extracs all properties of module."
    @spec extract_props(atom) :: [{atom, arity}]
    def extract_props(mod) do
      apply(mod,:__info__, [:functions])
        |> Stream.filter(
          fn {f, 0} -> f
              |> Atom.to_string
              |> String.starts_with? "prop_"
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


end
