defmodule PropCheck.StateM.ModelDSL do
  @moduledoc """
  This module provides a shallow DSL (domain specific language) in Elixir for
  property based testing of stateful systems. It's built upon `PropCheck.StateM`
  and all it's the characteristics apply here as well. It's a replacement for
  `PropCheck.StateM.DSL`.

  ## The basic approach

  Property based testing of stateful systems is different from ordinary property
  based testing. Instead of testing operations and their effects on the data
  structure directly, we construct a model of the system and generate a sequence
  of commands operating on both, the model and the system. Then we check that
  after each command step, the system has evolved accordingly to the model.
  This is the same idea which is used in model checking and is sometimes called
  a bisimulation.

  After defining a model, we have two phases during executing the property.  In
  phase 1, the generators create a list of (symbolic) commands including their
  parameters to be run against the system under test (SUT). A state machine
  guides the generation of commands.

  In phase 2, the commands are executed and the state machine checks that  the
  SUT is in the same state as the state machine. If an invalid state is
  detected, then the command sequence is shrunk towards a shorter sequence
  serving then as counterexamples.

  This approach works exactly the same as with `PropCheck.StateM` and
  `PropCheck.FSM`. The main difference is the API, grouping pre- and
  postconditions, state transitions around the commands of the SUT. This leads
  towards more logical locality compared to the former implementations.
  QuickCheck EQC has a similar approach for structuring their modern state
  machines.

  ## The DSL

  A state machine acting as a model of the SUT can be defined by focusing on
  states or on transitions. We focus here on the transitions. A transition is a
  command calling the SUT. Therefore the main phrase of the DSL is the
  `defcommand` macro.

      defcommand :find do
        # define the rules for executing the find command here
      end

  Inside the `defcommand` macro, we define all the rules which the command must
  obey. As an example, we discuss here as an example the slightly simplified
  command `:find` from `test/cache_dsl_test.exs`. The SUT is a cache
  implementation based on an ETS and the model is is based on a list of
  (key/value)-pairs. This example is derived from [Fred Hebert's PropEr Testing,
  Chapter 9](http://propertesting.com/book_stateful_properties.html)

  The `find`-command is a call to the `find/1` API function. Its arguments are
  generated in `c:command_gen/1` (described later) callback, which for this
  command is using just one argument, a `key()` generator. Next, we need to
  define the execution of the command by defining function `impl/n`.  The
  `impl`-function allows to apply conversion of parameters and return values to
  ease the testing. A typical example is the conversion of an `{:ok, value}`
  tuple to only `value` which can simplify working with `value`.

      defcommand :find do
        def impl(key), do: Cache.find(key)
      end

  After defining how a command is executed, we need to define in which state
  this is allowed. For this, we define function `pre/2`, taking the model state
  and the generated list of arguments to check whether this call is allowed in
  the current model state. In this particular example, `find` is always allowed,
  hence we return `true` without any further checking. This is also the default
  implementation and the reason why the precondition is missing in the test
  file.

      defcommand :find do
        def impl(key), do: Cache.find(key)
        def pre(_state, [_key]), do: true
      end

  If the precondition is satisfied, the call can happen. After the call, the SUT
  can be in a different state and the model state must be updated according to
  the mapping of the SUT to the model. The function `next/3` takes the state
  before the call, the list of arguments and the symbolic or dynamic result
  (depending on phase 1 or 2, respectively). `next/3` returns the new model
  state. Since searching for a key in the cache does not modify the system nor
  the model state, nothing has to be done. This is again the default
  implementation and thus left out in the test file.

      defcommand :find do
        def impl(key), do: Cache.find(key)
        def pre(_state, [_key]), do: true
        def next(old_state, _args, call_result), do: old_state
      end

  The missing part of the command definition is the post condition, checking
  that after calling the system in phase 2, the system is in the expected state
  compared the model. This check is implemented in function `post/3`, which
  again has a trivial default implementation for post conditions that always
  returns true. In this example, we check if we can find the key in our list of
  `entries` and if we do, we check if `call_result` resulted in `{:ok, val}`. Or
  if we don't found it, we check if the SUT also cannot find it by comparing if
  `call_result` returned `{:error, :not_found}`.

      defcommand :find do
        def impl(key), do: Cache.find(key)
        def pre(_state, [_key]), do: true
        def next(old_state, _args, _call_result), do: old_state
        def post(entries, [key], call_result) do
          case List.keyfind(entries, key, 0, false) do
              false       -> call_result == {:error, :not_found}
              {^key, val} -> call_result == {:ok, val}
          end
        end
      end

  This completes the DSL for command definitions.

  ## Additional model elements

  In addition to commands, we need to define the model itself. This is the
  ingenious part of stateful property based testing! The initial state of the
  model must be implemented as the function `initial_state/0`. It doesn't accept
  any arguments, because this function has to be deterministic. From this
  function, all model evolutions start. In our simplified cache example the
  initial model is an empty list:

      def initial_state(), do: []

  The sequence of commands to be run is generated repeatedly by
  `c:command_gen/1` callback. The generator has to return a tuple of with a
  command name and a list of it's arguments (a list of generators). This
  callback expects the current state as an argument, which often is used to
  determine the next one from a set of appropriate commands (e.g. there might
  not be much sense in calling the `delete_user` command, if there are no users
  in the system yet). Usually a `PropCheck.BasicTypes.oneof/1` or
  `PropCheck.BasicTypes.frequency/1` generators are used to pick one of possible
  commands. In our cache example we want the `find` command to appear three
  times more often than other commands:

      def command_gen(_state) do
        frequency([
          {3, {:find, [key()]}},
          {1, {:cache, [key(), val()]}},
          {1, {:flush, []}}
        ])

  ## The property to test

  The property to test the stateful system is more or less the same for all systems.
  We generate all commands via generator `commands/1`, which takes
  a module with callbacks as parameter. Inside the test, we first start
  the SUT, execute the commands with `run_commands/1`, stopping the SUT
  and evaluating the result of the executions as a boolean expression.
  This boolean expression can be adorned with further functions and macros
  to analyze the generated commands (via `PropCheck.aggregate/2`) or to
  inspect the history if a failure occurs (via `PropCheck.when_fail/2`).
  In the test cases, you find more examples of such adornments.

      property "run the sequential cache", [:verbose] do
        forall cmds <- commands(__MODULE__) do
          Cache.start_link(@cache_size)
          {_history, _state, result} = run_commands(cmds)
          Cache.stop()
          (result == :ok)
        end
      end

  ## Increasing the Number of Commands in a Sequence

  Sometimes issues can hide when the command sequences are short. In order to
  tease out these hidden bugs we can increase the number of commands generated
  by using the `max_size` option in our property.

        property "run the sequential cache", [max_size: 250] do
        forall cmds <- commands(__MODULE__) do
          Cache.start_link(@cache_size)
          {_history, _state, result} = run_commands(cmds)
          Cache.stop()
          (result == :ok)
        end
  """

  @typedoc """
  Each result of a symbolic call is stored in a symbolic variable. Their values
  are opaque and can only used as whole.
  """
  @type symbolic_var :: :proper_statem.symbolic_var()

  @typedoc """
  A symbolic state can be anything and appears only during phase 1.
  """
  @type symbolic_state :: any

  @typedoc """
  A dynamic state can be anything and appears only during phase 2.
  """
  @type dynamic_state :: any

  @typedoc """
  A symbolic call is the typical mfa-tuple plus the tag `:call`.
  """
  @type symbolic_call :: :proper_statem.symbolic_call()

  @typedoc """
  A value of type `command` denotes the execution of a symbolic command and
  storing its result in a symbolic variable.
  """
  @type command :: {:set, symbolic_var, symbolic_call} | {:init, symbolic_state}

  @typedoc """
  A sequence of commands.
  """
  @type command_list :: [command]

  @typedoc """
  A parallel testcase consists of a sequential and a parallel component. The
  sequential component is a command sequence that is run first to put the system
  in a random state. The parallel component is a list containing 2 command
  sequences to be executed in parallel, each of them in a separate newly-spawned
  process.
  """
  @type parallel_testcase :: {command_list, [command_list]}

  @typedoc """
  The history of concurrent execution of commands in phase 2.
  """
  @type parallel_history :: [{command, term}]

  @typedoc """
  History of command execution in phase 2. It contains current dynamic state and
  the result of the call.
  """
  @type history :: [{dynamic_state, term}]

  @typedoc """
  The outcome of the command sequence execution.
  """
  @type result :: :proper_statem.statem_result

  @doc """
  Specifies the symbolic initial state of the state machine.

  This state will be evaluated at command execution time to produce the actual
  initial state. The function is not only called at command generation time, but
  also in order to initialize the state every time the command sequence is run
  (i.e. during normal execution, while shrinking and when checking a
  counterexample). For this reason, it should be deterministic and
  self-contained.
  """
  @callback initial_state() :: symbolic_state

  @doc """
  Generates a symbolic call to be included in the command sequence, given the
  current state `s` of the abstract state machine. Must return a type that
  generates tuples
  `{command_name :: atom, args :: [PropCheck.BasicTypes.type]}`.

  However, before the call is actually included, a precondition is checked. This
  function will be repeatedly called to produce the next call to be included in
  the test case.
  """
  @callback command_gen(s :: symbolic_state) :: PropCheck.BasicTypes.type

  defmacro __using__(_options) do
    quote do
      @behaviour :proper_statem
      import unquote(__MODULE__)
      Module.register_attribute __MODULE__, :commands, accumulate: true
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(env) do
    commands =
      Module.get_attribute(env.module, :commands)
      |> Enum.map(&String.to_atom/1)

    [
      def_preconds(commands),
      def_postconds(commands),
      def_next_states(commands),
      def_commands(),
    ]
  end

  def def_commands do
    quote do
      def __all_commands__, do: @commands

      @impl :proper_statem
      def command(state) do
        import PropCheck, only: [let: 2]
        let {cmd, args} <- command_gen(state) do
          {:call, __MODULE__, cmd, args}
        end
      end
    end
  end

  def def_preconds(commands) do
    for cmd_name <- commands do
      quote do
        @impl :proper_statem
        def precondition(state, {:call, __MODULE__, unquote(cmd_name), args}) do
          unquote(:"#{cmd_name}_pre")(state, args)
        end
      end
    end
  end

  def def_postconds(commands) do
    for cmd_name <- commands do
      quote do
        @impl :proper_statem
        def postcondition(state, {:call, __MODULE__, unquote(cmd_name), args}, res) do
          unquote(:"#{cmd_name}_post")(state, args, res)
        end
      end
    end
  end

  def def_next_states(commands) do
    for cmd_name <- commands do
      quote do
        @impl :proper_statem
        def next_state(state, res, {:call, __MODULE__, unquote(cmd_name), args}) do
          unquote(:"#{cmd_name}_next")(state, args, res)
        end
      end
    end
  end

  @known_suffixes [:pre, :post, :next]
  @doc """
  Defines a new command of the model.

  Inside the command, local functions define
  * how the command is executed: `impl(...)` - this is required,
  * if the command is allowed in the current model state:
    `pre(state, arg_list) :: boolean` - this is `true` per default,
  * what the next state of the model is after the call:
    `next(old_state, arg_list, result) :: new_state` - the default
    implementation does not change the model state, sufficient for queries,
  * if the system under test is in the correct state after the call:
    `post(old_state, arg_list, result) :: boolean` - this is `true` in the
    default implementation.

  These local functions inside the macro are effectively callbacks to guide and
  evolve the model state.
  """
  defmacro defcommand(name, do: block) do
    pre  = String.to_atom("#{name}_pre")
    next = String.to_atom("#{name}_next")
    post = String.to_atom("#{name}_post")
    quote do
      def unquote(pre)(_state, _call), do: true
      def unquote(next)(state, _call, _result), do: state
      def unquote(post)(_state, _call, _res), do: true
      defoverridable [{unquote(pre), 2}, {unquote(next), 3}, {unquote(post), 3}]
      @commands Atom.to_string(unquote(name))

      unquote(Macro.postwalk(block, &rename_def_in_command(&1, name)))
    end
  end

  defp rename_def_in_command({:def, c1, [{:impl, c2, impl_args}, impl_body]}, name) do
    {:def, c1, [{name, c2, impl_args}, impl_body]}
  end
  defp rename_def_in_command({:def, c1, [{suffix_name, c2, args}, body]}, name)
  when suffix_name in @known_suffixes do
    new_name = String.to_atom("#{name}_#{suffix_name}")
    {:def, c1, [{new_name, c2, args}, body]}
  end
  defp rename_def_in_command(ast, _name) do
    ast
  end

  @doc """
  Extracts the names of the commands from a given command sequence, in
  the form of MFAs.

  It is useful in combination with functions such as
  `PropCheck.aggregate/2` in order to collect statistics about command
  execution.
  """
  defdelegate command_names(cmds), to: :proper_statem

  @doc """
  A special PropEr type which generates random command sequences,
  according to an abstract state machine specification.

  The function takes as
  input the name of a callback module, which contains the state machine
  specification. The initial state is computed by `mod:initial_state/0`.
  """
  defdelegate commands(mod), to: :proper_statem

  @doc """
  Similar to `commands/1`, but generated command sequences always
  start at a given state.

  In this case, the first command is always
  `{:init, initial_state}` and is used to correctly initialize the state
  every time the command sequence is run (i.e. during normal execution,
  while shrinking and when checking a counterexample). In this case,
  `mod:initial_state/0` is never called.
  """
  defdelegate commands(mod, initial_state), to: :proper_statem

  @doc """
  Increases the expected length of command sequences generated from
  `cmd_type` by a factor `n`.

  **CAVEAT**<br>
  This function does not work properly. My current guess is that this is
  a limitation of how PropEr works with sizing an din particular resizing.
  The commands list generator (`cmd_type`) is not a simple list which can
  be sized easily, but a complex construct where the rather simple approach
  of resizing does not work as expected.

  """
  def more_commands(n, cmd_type) do
    require PropCheck
    require PropCheck.BasicTypes

    PropCheck.sized(size, PropCheck.BasicTypes.resize(size * n, cmd_type))
  end

  @doc """
  A special PropEr type which generates parallel test cases,
  according to an abstract state machine specification.

  The function takes as
  input the name of a callback module, which contains the state machine
  specification. The initial state is computed by `mod:initial_state/0`.
  """
  defdelegate parallel_commands(mod), to: :proper_statem

  @doc """
  Similar to `parallel_commands/1`, but generated command sequences
  always start at a given state.
  """
  defdelegate parallel_commands(mod, initial_state), to: :proper_statem

  @doc """
  Evaluates a given symbolic command sequence `cmds` according to the
  state machine specified in `mod`.

  The result is a triple of the form
  `{history, dynamic_state, result}`, where:

  * `history` contains the execution history of all commands that were
    executed without raising an exception. It contains tuples of the form
    `{t:dynamic_state, t:term}`, specifying the state prior to
    command execution and the actual result of the command.
  * `dynamicState` contains the state of the abstract state machine at
    the moment when execution stopped. In case execution has stopped due to a
    false postcondition, `dynamic_state` corresponds to the state prior to
    execution of the last command.
  * `result` specifies the outcome of command execution. It can be
    classified in one of the following categories:
    <ul>
    <li> *ok*
      <br>All commands were successfully run and all postconditions were true.
    <li> *initialization error*
      <br>There was an error while evaluating the initial state.
    <li> *postcondition error*
      <br>A postcondition was false or raised an exception.
    <li> *precondition error*
      <br>A precondition was false or raised an exception.
    <li> *exception*
      <br>An exception was raised while running a command.
    </ul>
  """
  defdelegate run_commands(mod, cmds), to: :proper_statem

  @doc """
  Similar to `run_commands/2`, but also accepts an environment,
  used for symbolic variable evaluation during command execution. The
  environment consists of `{key::atom, value::any}` pairs. Keys may be
  used in symbolic variables (i.e. `{:var, key}`) within the command sequence
  `cmds`. These symbolic variables will be replaced by their corresponding
  `value` during command execution.
  """
  defdelegate run_commands(mod, cmds, env), to: :proper_statem

  @doc """
  Runs a given parallel test case according to the state machine
  specified in `mod`.

  The result is a triple of the form
  `{sequential_history, parallel_history, result}`, where:

  * `sequential_history` contains the execution history of the
    sequential component.
  * `Parallel_history` contains the execution history of each of the
    concurrent tasks.
  * `Result` specifies the outcome of the attempt to serialize command
    execution, based on the results observed. It can be one of the following:
    <ul><li> `ok` <li> `no_possible_interleaving` </ul>
  """
  defdelegate run_parallel_commands(mod, testcase),  to: :proper_statem

  @doc """
  Similar to `run_parallel_commands/2`, but also accepts an
  environment used for symbolic variable evaluation, exactly as described in
  `run_commands/3`.
  """
  defdelegate run_parallel_commands(mod, testcase, env), to: :proper_statem

  @doc """
  Returns the symbolic state after running a given command sequence,
  according to the state machine specification found in `mod`.

  The commands are not actually executed.
  """
  defdelegate state_after(mod, cmds), to: :proper_statem

  @doc """
  Behaves exactly like `Enum.zip/2`.

  Zipping stops when the shortest list stops. This is
  useful for zipping a command sequence with its (failing) execution history.

  """
  defdelegate zip(l1, l2), to: :proper_statem

  @doc """
  Print pretty report of the failed command run.

  Accepts options:
  * `return_values` - whether to print return values after each command run
  (default `true`),
  * `last_state` - whether section with the last state should be present
  (default `true`),
  * `pre_cmd_state` - whether to print state prior to executed command
  (default `false`),
  * `post_cmd_state` - whether to print state post executed command
  (default `true`),
  * `cmd_args` - whether to print command arguments as literals
  (default `true`),
  * `inspect_opts` - options passed to `inspect/2`
  """
  defdelegate print_report(run_result, cmds, opts \\ []),
    to: PropCheck.StateM.Reporter
end
