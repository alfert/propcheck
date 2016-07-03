defmodule PropCheck.StateM do
  @moduledoc """
  This module defines the `:proper_statem` behaviour, useful for testing
  stateful reactive systems whose internal state and side-effects are
  specified via an abstract state machine. Given a callback module
  implementing the `:proper_statem` behaviour (i.e. defining an abstract state
  machine of the system under test), PropEr can generate random symbolic
  sequences of calls to that system.

  As a next step, generated symbolic calls are actually performed, while
  monitoring the system's responses to ensure it behaves as expected. Upon
  failure, the shrinking mechanism attempts to find a minimal sequence of
  calls provoking the same error.


  ## The role of commands
  Testcases generated for testing a stateful system are lists of symbolic API
  calls to that system. Symbolic representation has several benefits, which
  are listed here in increasing order of importance:

   * Generated testcases are easier to read and understand.
   * Failing testcases are easier to shrink.
   * The generation phase is side-effect free and this results in
    repeatable testcases, which is essential for correct shrinking.

  Since the actual results of symbolic calls are not known at generation time,
  we use symbolic variables (`t:symb_var()`) to refer to them.
  A command (`t:command()`) is a symbolic term, used to bind a symbolic
  variable to the result of a symbolic call. For example:

      [{:set, {:var, 1}, {:call, :erlang, :put, [:a, 42]}},
      {:set, {:var, 2}, {:call, :erlang, :erase, [:a]}},
      {:set, {:var, 3}, {:call, :erlang, :put, [:b, {:var, 2}]}}]

  is a command sequence that could be used to test the process dictionary.
  In this example, the first call stores the pair `{:a, 42}` in the process
  dictionary, while the second one deletes it. Then, a new pair `{:b, {:var, 2}}`
  is stored. `{:var, 2}` is a symbolic variable bound to the result of
  `:erlang.erase/1`. This result is not known at generation time, since none of
  these operations is performed at that time. After evaluating the command
  sequence at runtime, the process dictionary will eventually contain the
  pair `{:b, 42}`.

  ## The abstract model-state
  In order to be able to test impure code, we need a way to track its
  internal state (at least the useful part of it). To this end, we use an
  abstract state machine representing the possible configurations of the
  system under test. When referring to the *model state*, we mean the
  state of the abstract state machine. The *model state* can be either
  symbolic or dynamic:

   * During command generation, we use symbolic variables to bind the
     results of symbolic calls. Therefore, the model state might
     (and usually does) contain symbolic variables and/or symbolic calls, which
     are necessary to operate on symbolic variables. Thus, we refer to it as
     symbolic state. For example, assuming that the internal state of the
     process dictionary is modeled as a proplist, the model state after
     generating the previous command sequence will be `[b: {:var, 2}}]`.
   * During runtime, symbolic calls are evaluated and symbolic variables are
     replaced by their corresponding real values. Now we refer to the state as
     dynamic state. After running the previous command sequence, the model state
    will be `[b: 42]`.


  ## The callback functions
  The following functions must be exported from the callback module
  implementing the abstract state machine:

   * `c:initial_state/0`
   * `initial_state() :: symbolic_state`
   * `command(s::symbolic_state) :: proper_types:type`
   * `precondition(s::symbolic_state, call::symb_call :: boolean`
   * `postcondition(s::dynamic_state,
                     call::symbolic_call,
                     res::term :: boolean`
   * `next_state(s::symbolic_state |dynamic_stat,
                  res::term,
                  call::symbolic_call) ::
                  symbolic_state | dynamic_state`


  ## The property used
  Each test consists of two phases:

   * As a first step, PropEr generates random symbolic command sequences
    deriving information from the callback module implementing the abstract
    state machine. This is the role of `commands/1` generator.
   * As a second step, command sequences are executed so as to check that
    the system behaves as expected. This is the role of
    `run_commands/2`, a function that evaluates a symbolic command
    sequence according to an abstract state machine specification.


  These two phases are encapsulated in the following property, which can be
  used for testing the process dictionary:

      def prop_pdict() do
        forall cmds <- commands(__MODULE__) do
          {_history, _state, result} = run_commands(__MODULE__, cmds)
          cleanup()
          result == ok
        end
      end


  When testing impure code, it is very important to keep each test
  self-contained. For this reason, almost every property for testing stateful
  systems contains some clean-up code. Such code is necessary to put the
  system in a known state, so that the next test can be executed
  independently from previous ones.

  ## Parallel testing
  After ensuring that a system's behaviour can be described via an abstract
  state machine when commands are executed sequentially, it is possible to
  move to parallel testing. The same state machine can be used to generate
  command sequences that will be executed in parallel to test for race
  conditions. A parallel testcase (`t:parallel_testcase`) consists of
  a sequential and a parallel component. The sequential component is a
  command sequence that is run first to put the system in a random state.
  The parallel component is a list containing 2 command sequences to be
  executed in parallel, each of them in a separate newly-spawned process.

  Generating parallel test cases involves the following actions. Initially,
  we generate a command sequence deriving information from the abstract
  state machine specification, as in the case of sequential statem testing.
  Then, we parallelize a random suffix (up to 12 commands) of the initial
  sequence by splitting it into 2 subsequences that will be executed
  concurrently. Limitations arise from the fact that each subsequence should
  be a *valid* command sequence (i.e. all commands should satisfy
  preconditions and use only symbolic variables bound to the results of
  preceding calls in the same sequence). Furthermore, we apply an additional
  check: we have to ensure that preconditions are satisfied in all possible
  interleavings of the concurrent tasks. Otherwise, an exception might be
  raised during parallel execution and lead to unexpected (and unwanted) test
  failure. In case these constraints cannot be satisfied for a specific test
  case, the test case will be executed sequentially. Then an `f` is printed
  on screen to inform the user. This usually means that preconditions need
  to become less strict for parallel testing to work.

  After running a parallel testcase, PropEr uses the state machine
  specification to check if the results observed could have been produced by
  a possible serialization of the parallel component. If no such serialization
  is possible, then an atomicity violation has been detected. In this case,
  the shrinking mechanism attempts to produce a counterexample that is minimal
  in terms of concurrent operations. Properties for parallel testing are very
  similar to those used for sequential testing.

      def prop_parallel_testing() do
         forall testcase <- parallel_commands(__MODULE__) do
            {_sequential, _parallel, result} = run_parallel_commands(__MODULE__, testcase),
            cleanup(),
            result == :ok
         end
      end

  Please note that the actual interleaving of commands of the parallel
  component depends on the Erlang scheduler, which is too deterministic.
  For PropEr to be able to detect race conditions, the code of the system
  under test should be instrumented with `erlang:yield/0` calls to the
  scheduler.

  ## Acknowldgements
  Very much of the documentation is immediately taken from the
  `proper` API documentation.
  """

  defmacro __using__(_) do
    quote do
      @behaviour :proper_statem
      use PropCheck
      import PropCheck.StateM
    end
  end

  @type symb_var :: :proper_statem.symb_var
  @type command :: :proper_statem.command

  @doc """
  Specifies the symbolic initial state of the state machine.

  This state
  will be evaluated at command execution time to produce the actual initial
  state. The function is not only called at command generation time, but
  also in order to initialize the state every time the command sequence is
  run (i.e. during normal execution, while shrinking and when checking a
  counterexample). For this reason, it should be deterministic and
  self-contained.
  """
  @callback initial_state() :: :proper_statem.symbolic_state

  @doc """
  Generates a symbolic call to be included in the command sequence,
  given the current state `s` of the abstract state machine.

  However,
  before the call is actually included, a precondition is checked. This
  function will be repeatedly called to produce the next call to be
  included in the test case.
  """
  @callback command(s :: :proper_statem.symbolic_state) :: :proper_types.type

  @doc """
  Specifies the precondition that should hold so that `call` can be
  included in the command sequence, given the current state `s` of the
  abstract state machine.

  In case precondition doesn't hold, a new call is
  chosen using the `command/1` generator. If preconditions are very strict,
  it will take a lot of tries for PropEr to randomly choose a valid command.
  Testing will be stopped in case the `constraint_tries` limit is reached
  (see the `Options` section in the {@link proper} module documentation).
  Preconditions are also important for correct shrinking of failing
  testcases. When shrinking command sequences, we try to eliminate commands
  that do not contribute to failure, ensuring that all preconditions still
  hold. Validating preconditions is necessary because during shrinking we
  usually attempt to perform a call with the system being in a state
  different from the state it was when initially running the test.
  """
  @callback precondition(s :: :proper_statem.symbolic_state, call :: :proper_statem.symb_call) :: boolean

  @doc """
  Specifies the postcondition that should hold about the result `res` of
  performing `call`, given the dynamic state `s` of the abstract state
  machine prior to command execution.

  This function is called during
  runtime, this is why the state is dynamic.
  """
  @callback postcondition(s :: :proper_statem.dynamic_state,
    call:: :proper_types.symbolic_call, res :: term) :: boolean

  @doc """
  Specifies the next state of the abstract state machine, given the
  current state `s`, the symbolic `call` chosen and its result `Res`. This
  function is called both at command generation and command execution time
  in order to update the model state, therefore the state `s` and the
  result `Res` can be either symbolic or dynamic.
  """
  @callback next_state(:proper_statem.symbolic_state | :proper_statem.dynamic_state,
    term, :proper_statem.symbolic_call) ::
    :proper_statem.symbolic_state | :proper_statem.dynamic_state

  @doc """
  Extracts the names of the commands from a given command sequence, in
  the form of MFAs.

  It is useful in combination with functions such as
  `PropCheck.aggregate/2` in order to collect statistics about command
  execution.
  """
  defdelegate command_names(cmds), to: :proper_statem

  @doc """
  A special PropEr type which generates random command sequences,
  according to an absract state machine specification.

  The function takes as
  input the name of a callback module, which contains the state machine
  specification. The initial state is computed by `mod:initial_state/0`.
  """
  defdelegate commands(mod), to: :proper_statem

  @doc """
  Similar to `commands/1`, but generated command sequences always
  start at a given state.

  In this case, the first command is always
  `{:init, initial_state}` and is used to correctly initialize the state
  every time the command sequence is run (i.e. during normal execution,
  while shrinking and when checking a counterexample). In this case,
  `mod:initial_state/0` is never called.
  """
  defdelegate commands(mod, initial_state), to: :proper_statem

  @doc """
  Increases the expected length of command sequences generated from
  `cmd_type` by a factor `n`.
  """
  defdelegate more_commands(n, cmd_type), to: :proper_statem

  @doc """
  A special PropEr type which generates parallel testcases,
  according to an absract state machine specification.

  The function takes as
  input the name of a callback module, which contains the state machine
  specification. The initial state is computed by `mod:initial_state/0`.
  """
  defdelegate parallel_commands(mod), to: :proper_statem

  @doc """
  Similar to `parallel_commands/1`, but generated command sequences
  always start at a given state.
  """
  defdelegate parallel_commands(mod, initial_state), to: :proper_statem

  @doc """
  Evaluates a given symbolic command sequence `cmds` according to the
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
  Similar to `run_commands/2`, but also accepts an environment,
  used for symbolic variable evaluation during command execution. The
  environment consists of `{key::atom, value::any}` pairs. Keys may be
  used in symbolic variables (i.e. `{:var, key}`) whithin the command sequence
  `cmds`. These symbolic variables will be replaced by their corresponding
  `value` during command execution.
  """
  defdelegate run_commands(mod, cmds, env), to: :proper_statem

  @doc """
  Runs a given parallel testcase according to the state machine
  specified in `mod`.

  The result is a triple of the form
  `{sequential_history, parallel_history, result}`, where:

  * `sequential_history` contains the execution history of the
    sequential component.
  * `Parallel_history` contains the execution history of each of the
    concurrent tasks.
  * `Result` specifies the outcome of the attemp to serialize command
    execution, based on the results observed. It can be one of the following:
    <ul><li> `ok` <li> `no_possible_interleaving` </ul>
  """
  defdelegate run_parallel_commands(mod, testcase),  to: :proper_statem

  @doc """
  Similar to `run_parallel_commands/2`, but also accepts an
  environment used for symbolic variable evaluation, exactly as described in
  `run_commands/3`.
  """
  defdelegate run_parallel_commands(mod, testcase, env), to: :proper_statem

  @doc """
  Returns the symbolic state after running a given command sequence,
  according to the state machine specification found in `mod`.

  The commands are not actually executed.
  """
  defdelegate state_after(mod, cmds), to: :proper_statem

  @doc """
  Behaves exactly like `Enum.zip/2`.

  Zipping stops when the shortest list stops. This is
  useful for zipping a command sequence with its (failing) execution history.

  """
  defdelegate zip(l1, l2), to: :proper_statem

end
