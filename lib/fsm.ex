defmodule PropCheck.FSM do
  @moduledoc """
  The finite state machine approach for stateful systems, which is closer
  to Erlangs `gen_fsm` model.

  This module defines the `proper_fsm` behaviour, useful for testing
  systems that can be modeled as finite state machines. That is, a finite
  collection of named states and transitions between them. `PropCheck.FSM` is
  closely related to `PropCheck.StateM` and is, in fact, implemented in
  terms of that. Testcases generated using `PropCheck.FSM` will be on precisely
  the same form as testcases generated using `PropCheck.StateM`. The
  difference lies in the way the callback modules are specified.
  The relation between `PropCheck.StateM` and `PropCheck.FSM` is similar
  to the one between `gen_server` and `gen_fsm` in OTP libraries.

  Due to name conflicts with functions automatically imported from
  `PropCheck.StateM`, a fully qualified call is needed in order to
  use the  <a href="#functions">API functions </a> of `PropCheck.FSM`.

  ## The states of the finite state machine

  Following the convention used in `gen_fsm behaviour`, the state is
  separated into types `t:state_name/0` and some
  `t:state_data/0`. `state_name` is used to denote a state
  of the finite state machine and `state_data` is any relevant information
  that has to be stored in the model state. States are fully
  represented as tuples `{state_name, state_data}`.

  `state_name` is usually an atom (i.e. the name of the state), but can also
  be a tuple. In the latter case, the first element of the tuple must be an
  atom specifying the name of the state, whereas the rest of the elements can
  be arbitrary terms specifying state attributes. For example, when
  implementing the fsm of an elevator which can reach n different floors, the
  `state_name` for each floor could be `{:floor, k}, 1 <= k <= n`.<br/>
  `state_data` can be an arbitrary term, but is usually a record.

  ## Transitions between states

  A transition `t:transition/0` is represented as a tuple
  `{target_state, {:call, m, f, a}}`. This means that performing the specified
  symbolic call at the current state of the fsm will lead to `target_state`.
  The atom `:history` can be used as `target_state` to denote that a transition
  does not change the current state of the fsm.

  ## The callback functions

  The following functions must be exported from the callback module
  implementing the finite state machine:

  * `c:initial_state/0`
  * `c:initial_data/0`
  * `c:precondition/4`
  * `c:postcondition/5`
  * `c:next_state_data/5`
  * `c:weight/3`

  In addition to these functions, we also need functions for each
  state:

  * `state_name(s::state_data) ::[transition]`
    <br>There should be one instance of this function for each reachable
    state `state_name` of the finite state machine. In case `state_name` is a
    tuple the function takes a different form, described just below. The
    function returns a list of possible transitions (`t:transition/0` )
    from the current state.

    At command generation time, the instance of this function with the same
    name as the current state's name is called to return the list of possible
    transitions. Then, PropEr will randomly choose a transition and,
    according to that, generate the next symbolic call to be included in the
    command sequence. However, before the call is actually included, a
    precondition that might impose constraints on `state_data` is checked.

    Note also that PropEr detects transitions that would raise an exception
    of class `<error>` at generation time (not earlier) and does not choose
    them. This feature can be used to include conditional transitions that
    depend on the `t:state_data/0`.
  * `state_name(attr1::any, ..., attrN::any,
                  s::type state_data) :: [transition]`
    <br>There should be one instance of this function for each reachable state
    `{state_name, attr1, ..., attrN}` of the finite state machine. The function
    has similar beaviour to `state_name/1`, described above.

  ## The property used

  This is an example of a property that can be used to test a
  finite state machine specification. It expects a `cleanup` function
  that takes care of removing all artifacts created during tests to
  enable a clean start for each test case execution.

      property "fsm" do
         forall cmds <- commands(__MODULE__) do
           {_history, _state, result} = run_commands(__MODULE__, cmds)
           cleanup()
           result == :ok
        end
      end

  """

  defmacro __using__(_) do
    quote do
      @behaviour :proper_fsm
      use PropCheck
      import PropCheck.FSM
    end
  end

  @type mod_name :: atom
  @type state_name :: atom | tuple
  @type state_data :: any
  @type symb_call :: PropCheck.StateM.symb_call
  @type symb_var :: PropCheck.StateM.symb_var
  @type fsm_state()    :: {state_name, state_data}
  @type transition()   :: {state_name, symb_call}
  @type history()      :: [{fsm_state,cmd_result}]

  @type result :: :proper_statem.statem_result
  @type fsm_result :: result
  @type cmd_result :: any
  @type command  :: {:set ,symb_var,symb_call} | {:init, fsm_state()}
  @type command_list:: [command]


  @doc """
  Specifies the initial state of the finite state machine. As with
  `c:PropCheck.StateM.initial_state/0`, its result should be deterministic.
  """
  @callback initial_state() :: state_name

  @doc """
  Specifies what the state data should initially contain. Its result
  should be deterministic.
  """
  @callback initial_data() :: state_data

  @doc """
  Similar to `c:PropCheck.StateM.precondition/2`.

  Specifies the
  precondition that should hold about `state_data` so that `call` can be
  included in the command sequence. In case precondition doesn't hold, a
  new transition is chosen using the appropriate `state_name/1` generator.

  It is possible for more than one transitions to be triggered by the same
  symbolic call and lead to different target states. In this case, at most
  one of the target states may have a true precondition. Otherwise, PropEr
  will not be able to detect which transition was chosen and an exception
  will be raised.
  """
  @callback precondition(from :: state_name, target:: state_name,
    state_data :: state_data, call :: symb_call) :: boolean

  @doc """
  Similar to `c:PropCheck.StateM.postcondition/3`. Specifies the
  postcondition that should hold about the result `res` of the evaluation
  of `call`.
  """
  @callback postcondition(from :: state_name, target:: state_name,
    state_data :: state_data, call :: symb_call, result :: result) :: boolean

  @doc """
  Similar to `c:PropCheck.StateM.next_state/3`. Specifies how the
  transition from `from` to `target` triggered by `call` affects the
  `state_data`. `res` refers to the result of `call` and can be either
  symbolic or dynamic.
  """
  @callback next_state_data(from :: state_name, target:: state_name,
    state_data :: state_data, result :: result, call :: symb_call) :: state_data

  @doc """
  This is an optional callback. When it is not defined (or not exported),
  transitions are chosen with equal probability. When it is defined, it
  assigns an integer weight to transitions from `from` to `target`
  triggered by symbolic call `call`. In this case, each transition is chosen
  with probability proportional to the weight assigned.
  """
  @callback weight(from::state_name, target::state_name, call::symb_call) :: integer
  @optional_callbacks weight: 3

  @doc """
  A special PropEr type which generates random command sequences,
  according to a finite state machine specification.

  The function takes as
  input the name of a callback module, which contains the fsm specification.
  The initial state is computed by
  `{mod.initial_state/0, mod:initial_state_data/0}`.
  """
  @spec commands(mod_name) :: PropCheck.type
  def commands(mod), do: :proper_fsm.commands(mod)

  @doc """
  Similar to `commands/1`, but generated command sequences always
  start at a given state.

  In this case, the first command is always
  `{:init, initial_state = {name, data}}` and is used to correctly initialize the
  state every time the command sequence is run (i.e. during normal execution,
  while shrinking and when checking a counterexample).
  """
  @spec commands(mod_name, fsm_state) :: PropCheck.type
  def commands(mod, initial_state), do: :proper_fsm.commands(mod, initial_state)

  defdelegate more_commands(n, cmd_type),           to: PropCheck.StateM

  @doc """
  Evaluates a given symbolic command sequence `cmds` according to the
  finite state machine specified in `mod`.

  The result is a triple of the form `{history, fsm_state, result}`,
  similar to `PropCheck.StateM.run_commands/2`.
  """
  @spec run_commands(mod_name, command_list) :: {history,fsm_state,fsm_result}
  def run_commands(mod, cmds), do: :proper_fsm.run_commands(mod, cmds)

  @doc """
  Similar to `run_commands/2`, but also accepts an environment
  used for symbolic variable evaluation, exactly as described in
  `PropCheck.StateM.run_commands/3`.
  """
  @spec run_commands(mod_name, command_list, :proper_symb.var_values) ::
           {history,fsm_state,fsm_result}
  def run_commands(mod, cmds, env), do: :proper_fsm.run_commands(mod, cmds, env)

  @doc """
  Extracts the names of the states from a given command execution history.

  It is useful in combination with functions such as `PropCheck.aggregate/2`
  in order to collect statistics about state transitions during command
  execution.
  """
  @spec state_names(history) :: [state_name]
  def state_names(history), do: :proper_fsm.state_names(history)

  defdelegate command_names(cmds), to: PropCheck.StateM
end
