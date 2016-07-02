defmodule PropCheck do
    @moduledoc """
    Provides the macros and functions for property based testing
    using `proper` as base implementation. `PropCheck` supports many
    features of `PropEr`, but the automated generation of test data
    generators is only partially supported due to internal features of
    `PropEr` focussing of Erlang only.

    ## Using PropCheck
    To use `PropCheck`, you need to add `use PropCheck` to your
    Elixir files. This gives you access to the functions and macros
    defined here as well as to the `property` macros. In most examples shown
    here, we directly use the `quickcheck` function, but typically you
    use the `property` macro instead to define test cases for `ExUnit`.

    Also availables are the value generators which are imported directly
    from `PropCheck.BasicTypes`.

    ## How to write properties
    The simplest properties that PropEr can test consist of a single boolean
    expression (or a statement block that returns a boolean), which is expected
    to evaluate to `true`. Thus, the test `true` always succeeds, while the test
    `false` always fails (the failure of a property may also be signified by
    throwing an exception, error or exit. More complex (and useful) properties
    can be written by wrapping such a boolean expression with one or more of the
    following wrappers:

    * `forall/2`
    * `implies/2`
    * `when_fail/2`
    * `trap_exit/1`
    * `conjunction/1`
    * `equals/2`

    There are also multiple wrappers that can be used to collect statistics on
    the distribution of test data:

    * `collect/2`
    * `collect/3`
    * `aggregate/2`
    * `aggregate/3`
    * `classify/3`
    * `measure/3`

    A property may also be wrapped with one or more of the following outer-level
    wrappers, which control the behaviour of the testing subsystem. If an
    outer-level wrapper appears more than once in a property, the innermost
    instance takes precedence.

    * `numtests/2`
    * `fails/1`
    * `on_output/2`

    For some actual usage examples, see the code in the examples directory, or
    check out PropEr's site. The testing modules in the tests directory may also
    be of interest.

    ## Program behaviour
    When running in verbose mode (this is the default), each sucessful test
    prints a `.` on screen. If a test fails, a `!` is printed, along with the
    failing test case (the instances of the types in every `forall`) and the
    cause of the failure, if it was not simply the falsification of the
    property.

    Then, unless the test was expected to fail, PropEr attempts to produce a
    minimal test case that fails the property in the same way. This process is
    called *shrinking*. During shrinking, a `.` is printed for each
    successful simplification of the failing test case. When PropEr reaches its
    shrinking limit or realizes that the instance cannot be shrunk further while
    still failing the test, it prints the minimal failing test case and failure
    reason and exits.

    The return value of PropEr can be one of the following:
    * `true`: The property held for all valid produced inputs.
    * `false`: The property failed for some input.
    * `{error, type_of_error}`: An error occured; see the {@section Errors}
     section for more information.<

    To test all properties exported from a module (a property is a 0-arity
    function whose name begins with `prop_`), you can use `module/1` or
    `module/2`. This returns a list of all failing properties, represented
    by MFAs. Testing progress is also printed on screen (unless quiet mode is
    active). The provided options are passed on to each property, except for
    `long_result`, which controls the return value format of the `module`
    function itself.

    ## Counterexamples
    A counterexample for a property is represented as a list of terms; each such
    term corresponds to the type in a `forall`. The instances are provided in
    the same order as the `forall` wrappers in the property, i.e. the instance
    at the head of the list corresponds to the outermost `forall` etc.
    Instances generated inside a failing sub-property of a conjunction are
    marked with the sub-property's tag.

    The last (simplest) counterexample produced by PropEr during a (failing) run
    can be retrieved after testing has finished, by running
    `counterexample/0`. When testing a whole module, run
    `counterexamples/0` to get a counterexample for each failing property,
    as a list of `{mfa, counterexample}` tuples. To enable this
    functionality, some information has to remain in the process dictionary
    even after PropEr has returned. If, for some reason, you want to completely
    clean up the process dictionary of PropEr-produced entries, run
    `clean_garbage/0`.

    Counterexamples can also be retrieved by running PropEr in long-result mode,
    where counterexamples are returned as part of the return value.
    Specifically, when testing a single property under long-result mode
    (activated by supplying the option `:long_result`, or by calling
    `counterexample/1` or `counterexample/2` instead of
    `quickcheck/1` and `quickcheck/2` respectively), PropEr will
    return a counterexample in case of failure (instead of simply returning
    `false`). When testing a whole module under long-result mode (activated by
    supplying the option `:long_result` to `module/2`), PropEr will return
    a list of `{mfa(), counterexample}` tuples, one for each failing
    property.

    You can re-check a specific counterexample against the property that it
    previously falsified by running `check/2` or `check/3`. This
    will return one of the following (both in short- and long-result mode):

    * `true`: The property now holds for this test case.
    * `false`: The test case still fails (although not necessarily for the
      same reason as before).
    * `{error, type_of_error}`: An error occured - see the {@section Errors}
      section for more information.

    PropEr will not attempt to shrink the input in case it still fails the
    property. Unless silent mode is active, PropEr will also print a message on
    screen, describing the result of the re-checking. Note that PropEr can do
    very little to verify that the counterexample actually corresponds to the
    property that it is tested against.

    ## Options
    Options can be provided as an extra argument to most testing functions (such
      as `quickcheck/1`). A single option can be written stand-alone, or
    multiple options can be provided in a list. When two settings conflict, the
    one that comes first in the list takes precedence. Settings given inside
    external wrappers to a property (see the {@section How to write properties}
    section) override any conflicting settings provided as options.

    The available options are:

    * `:quiet` <br> Enables quiet mode - no output is printed on screen while PropEr is
      running.
    * `:verbose` <br>
      Enables verbose mode - this is the default mode of operation.
    * `{:to_file, io_device}` <br>
     Redirects all of PropEr's output to `io_device`, which should be an
      IO device associated with a file opened for writing.
    * `{:on_output, output_function}` <br>
     PropEr will use the supplied function for all output printing. This
      function should accept two arguments in the style of `:io.format/2`.<br/>
      **CAUTION:** The above output control options are incompatible with each
      other.
    * `:long_result` <br>
     Enables long-result mode (see the {@section Counterexamples} section
      for details).
    * `{:numtests, positive_number}` or simply `positive_number` <br>
     This is equivalent to the `numtests/1` property wrapper. Any
        `numtests/1` wrappers in the actual property will overwrite this
      setting.
    * `{:start_size, size}` <br>
     Specifies the initial value of the `size` parameter (default is 1), see
      the documentation of the `PropCheck.BasicTypes` module for details.
    * `{:max_size, size}` <br>
     Specifies the maximum value of the `size` parameter (default is 42), see
      the documentation of the `PropCheck.BasicTypes` module for details.
    * `{:max_shrinks, non_negative_number}` <br>
     Specifies the maximum number of times a failing test case should be
      shrunk before returning. Note that the shrinking may stop before so many
      shrinks are achieved if the shrinking subsystem deduces that it cannot
      shrink the failing test case further. Default is 500.
    * `:noshrink` <br>
     Instructs PropEr to not attempt to shrink any failing test cases.
    * `{:constraint_tries, positive_number}` <br>
     Specifies the maximum number of tries before the generator subsystem
      gives up on producing an instance that satisfies a `such_that`
      constraint. Default is 50.
    * `fails` <br>
       This is equivalent to the `fails/1` property wrapper.
    * `{:spec_timeout, :infinity | <Non_negative_number>}` <br>
     When testing a spec, PropEr will consider an input to be failing if the
      function under test takes more than the specified amount of milliseconds
      to return for that input.
    * `:any_to_integer` <br>
       All generated instances of the type `PropCheck.BasicTypes.any/0` will be
      integers. This is provided as a means to speed up the testing of specs,
      where `any` is a commonly used type (see the {@section Spec testing}
      section for details).
    * `{:skip_mfas, [mfa]}` <br>
      When checking a module's specs, PropEr will not test the
      specified MFAs.  Default is [].
    * `{false_positive_mfas, ((mfa(), args::[any], {:fail, result::any} |
      {:error | :exit | :throw, reason::any}) -> boolean) | :undefined` <br>
      When checking a module's spec(s), PropEr will treat a
    counterexample as a false positive if the user supplied function
    returns true.  Otherwise, PropEr will treat the counterexample as
    it normally does.  The inputs to the user supplied function are
    the MFA, the arguments passed to the MFA, and the result returned
    from the MFA or an exception with it's reason.  If needed, the
      user supplied function can call `:erlang.get_stacktrace/0`.  Default
      is `:undefined`.

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

    @opaque counterexample :: :proper.counterexample
    @type user_opts :: [user_opt] | user_opt
    @type outer_test :: :proper.outer_test
    @type test :: :proper.test
    @type output_fun :: ((char_list,[term]) -> :ok)
    @type size :: non_neg_integer
    @type user_opt :: :quiet
    		  | :verbose
    		  | {:to_file, :io.device}
    		  | {:on_output, output_fun}
    		  | :long_result
    		  | {:numtests, pos_integer}
    		  | pos_integer
    		  | {:start_size, size}
    		  | {:max_size, size}
    		  | {:max_shrinks, non_neg_integer}
    		  | :noshrink
    		  | {:constraint_tries, pos_integer}
    		  | :fails
    		  | :any_to_integer
    		  | {:spec_timeout, timeout}
    		  | {:skip_mfas, [mfa]}
    		  | {:false_positive_mfas, false_positive_mfas}
    @type false_positive_mfas ::
      ((mfa(), args::[any], {:fail, result::any} |
        {:error | :exit | :throw, reason::any}) -> boolean) | :undefined
    @type error :: {:error, error_reason}
    @type error_reason :: :arity_limit | :cant_generate | :cant_satisfy
    		      | :non_boolean_result | :rejected | :too_many_instances
    		      | :type_mismatch | :wrong_type | {:typeserver, any}
    		      | {:unexpected, any} | {:unrecognized_option, any}

    @type long_result :: :true | counterexample | error
    @type short_result :: boolean | error
    @type result :: long_result | short_result
    @type long_module_result :: [{mfa,counterexample}] | error
    @type short_module_result :: [mfa] | error
    @type module_result :: long_module_result | short_module_result

    @type sample :: [any]
    @type title :: char_list | atom | String.t
    @type stats_printer :: ((sample) -> :ok)
    		       | ((sample, output_fun) -> :ok)

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
    defmacro forall(binding, property)
    defmacro forall({op, _, [var, rawtype]}, do: prop) when op in @in_ops do
        quote do
            :proper.forall(unquote(rawtype), fn(unquote(var)) -> unquote(prop) end)
        end
    end
    defmacro forall(_binding, _property), do: syntax_error("var <- generator, do: prop")

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

    An example for `sized` is shown in the documentation of  `let_shrink/2`.

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

    defmacro let([{:<-, _, _} | _rest] = bindings, [{:do, gen}]) do
        bound = let_bind(bindings) |> Enum.reverse
        vars = bound |> Enum.map(&(elem(&1, 0)))
        raw_types = bound |> Enum.map(&(elem(&1, 1)))
        quote do
          :proper_types.bind(unquote(raw_types),
            fn(unquote(vars)) -> unquote(gen) end, false)
        end
    end
    defp let_bind({:<-, _, [var, rawtype]} = _bind), do: {var, rawtype}
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
    defmacro such_that(binding, condition)
    defmacro such_that({:<-, _, [var, rawtype]}, condition)  do
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
    defmacro such_that_maybe(binding, condition)
    defmacro such_that_maybe({:<-, _, [x, rawtype]} = _binding, condition)  do
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

          iex> use PropCheck
          iex> tree_gen = fn (0, _, _) -> :leaf
          ...>               (s, g, tree) ->
          ...>      frequency [
          ...>       {1, tree.(0, g, tree)},
          ...>       {9, let_shrink([
          ...>         l <- tree.(div(s, 2), g, tree),
          ...>         r <- tree.(div(s, 2), g, tree)
          ...>         ]) do
          ...>           {:node, g, l, r}
          ...>         end
          ...>        }
          ...>   ]
          ...> end
          iex> tree = fn(g) -> sized(s, tree_gen.(s, g, tree_gen)) end
          iex> quickcheck(
          ...>   forall t <- tree.(int) do
          ...>     t == :leaf or is_tuple(t)
          ...>   end
          ...>)
          true

    """
    defmacro let_shrink({:<-, _, [var, rawtype]}, [do: gen]) do
        quote do
            :proper_types.bind(unquote(rawtype),
                fn(unquote(var)) -> unquote(gen) end, true)
        end
    end
    defmacro let_shrink([{:<-, _, _} | _rest] = bindings, [do: gen]) do
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
        _counter_example when should_fail -> true
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

    @doc """
    Retrieves the last (simplest) counterexample produced by PropCheck during
    the most recent testing run.
    """
    @spec counterexample() :: counterexample | :undefined
    def counterexample(), do: :erlang.get(:"$counterexample")

    @doc """
    Returns a counterexample for each failing property of the most recent
    module testing run.
    """
    @spec counterexamples() :: [{mfa,counterexample}] | :undefined
    def counterexamples(), do: :erlang.get(:"$counterexamples")

    @doc "Runs PropEr on the property `outer_test`."
    @spec quickcheck(outer_test) :: result
    def quickcheck(outer_test), do: quickcheck(outer_test, [])

    @doc "Same as `quickcheck/1`, but also accepts a list of options."
    @spec quickcheck(outer_test, user_opts) :: result
    defdelegate quickcheck(outer_test, user_opts), to: :proper

    # @equiv quickcheck(outer_test, [long_result])
    # @spec counterexample(outer_test) :: long_result
    # def counterexample(outer_test), do: counterexample(outer_test, [])

    @doc "Same as `counterexample/1`, but also accepts a list of options."
    @spec counterexample(outer_test, user_opts) :: long_result
    def counterexample(outer_test, user_opts \\ []), do:
      :proper.counterexample(outer_test, user_opts)

    @doc "Tests the accuracy of an exported function's spec."
    @spec check_spec(mfa, user_opts) :: result
    def check_spec(mfa, user_opts \\ []), do: :proper.check_spec(mfa, user_opts)

    @doc """
    Re-checks a specific counterexample `cexm` against the property
    `outer_test` that it previously falsified.
    """
    @spec check(outer_test, counterexample, user_opts) :: short_result
    def check(outer_test, cexm, user_opts \\ []), do:
      :proper.check(outer_test, cexm, user_opts)

    @doc """
    Tests all properties (i.e., all 0-arity functions whose name begins with
    `prop_`) exported from module `mod`
    """
    @spec module(atom, user_opts) :: module_result
    def module(mod, user_opts \\ []), do:
      :proper.module(mod, user_opts)

    @doc "Tests all exported, `-spec`ed functions of a module `mod` against their spec."
    @spec check_specs(atom, user_opts) :: module_result
    def check_specs(mod, user_opts \\ []), do: :proper.check_specs(mod, user_opts)

    @doc """
    Specifies the number `N` of tests to run when testing the property
    `property`.

    Default is 100.
    """
    @spec numtests(pos_integer, outer_test) :: outer_test
    def numtests(n, property), do: {:numtests, n, property}

    @doc """
    Specifies that we expect the property `property` to fail for some input.

    The property will be considered failing if it passes all the tests.
    """
    @spec fails(outer_test) :: outer_test
    def fails(property), do: {:fails, property}

    @doc """
    Specifies an output function `print` to be used by PropCheck for all output
    printing during the testing of property `property`.

    This wrapper is equivalent to the `on_output` option.
    """
    @spec on_output(output_fun, outer_test) :: outer_test
    def on_output(print, property), do: {:on_output, print, property}

    @doc """
    Specifies that test cases produced by this property should be
    categorized under the term `category`.

    This field can be an expression or
    statement block that evaluates to any term. All produced categories are
    printed at the end of testing (in case no test fails) along with the
    percentage of test cases belonging to each category. Multiple `collect`
    wrappers are allowed in a single property, in which case the percentages for
    each `collect` wrapper are printed separately.
    """
    @spec collect(any, test) :: test
    def collect(category, property), do: collect(with_title(''), category, property)

    @doc """
    Same as `collect/2`, but also accepts a fun `printer` to be used
    as the stats printer.
    """
    @spec collect(stats_printer, any, test) :: test
    def collect(printer, category, property), do:
        aggregate(printer, [category], property)

    @doc """
    Same as `collect/2`, but accepts a list of categories under which
    to classify the produced test case.
    """
    @spec aggregate(sample, test) :: test
    def aggregate(sample, property) do
        aggregate(with_title(''), sample, property)
    end

    @doc """
    Same as `collect/3`, but accepts a list of categories under which
    to classify the produced test case.
    """
    @spec aggregate(stats_printer(), sample(), test()) ::  test()
    def aggregate(printer, sample, property), do:
        {:sample, sample, printer, property}

    @doc """
    Same as `collect/2`, but can accept both a single category and a
    list of categories.

    `count` is a boolean flag: when `false`, the particular
    test case will not be counted.
    """
    @spec classify(boolean, any | sample, test):: test
    defdelegate classify(count, sample, test), to: :proper

    @doc """
    A function that collects numeric statistics on the produced instances.

    The number (or numbers) provided are collected and some statistics over the
    collected sample are printed at the end of testing (in case no test fails),
    prepended with `title`, which should be an atom or string.
    """
    @spec measure(title, number | [number], test) :: test
    def measure(title, num, test) when is_binary(title) do
      measure(String.to_char_list(title), num, test)
    end
    def measure(title, num, test), do: :proper.measure(title, num, test)

    @doc """
    A custom property that evaluates to `true` only if `a === b`, else
    evaluates to `false` and prints `"A != B"` on the screen.
    """
    @spec equals(any, any) :: test
    def equals(a, b), do:
        when_fail(:io.format('~w != ~w~n', [a, b]), a === b)

    @doc """
    A predefined function that accepts an atom or string and returns a
    stats printing function which is equivalent to the default one, but prints
    the given title `title` above the statistics.
    """
    @spec with_title(title) :: stats_printer
    def with_title(title) when is_binary(title), do: with_title(String.to_char_list(title))
    def with_title(title), do: :proper.with_title(title)

    @doc """
    Returns a property that is true only if all of the sub-properties
    `sub_properties` are true.

    Each sub-property should be tagged with a distinct atom.
    If this property fails, each failing sub-property will be reported and saved
    inside the counterexample along with its tag.
    """
    @spec conjunction([{atom, test}]) :: test()
    def conjunction(sub_properties), do: {:conjunction, sub_properties}

    # Helper functions
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
