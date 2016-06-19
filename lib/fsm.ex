defmodule PropCheck.FSM do
  @moduledoc """
  The finite state machine approach for stateful systems, which is closer
  to Erlangs `gen_fsm` model.
  """

  defmacro __using__(_) do
    quote do
      @behaviour :proper_fsm
      use PropCheck
      import PropCheck.FSM
    end
  end

  @type state_name :: atom | tuple
  @type state_data :: any
  @type symb_call :: :proper_statem.symb_call
  @type result :: :proper_statem.statem_result

  @callback initial_state() :: state_name
  @callback initial_data() :: state_data
  @callback precondition(from :: state_name, target:: state_name,
    state_data :: state_data, call :: symb_call) :: boolean
  @callback postcondition(from :: state_name, target:: state_name,
    state_data :: state_data, call :: symb_call, result :: result) :: boolean
    @callback next_state_data(from :: state_name, target:: state_name,
      state_data :: state_data, result :: result, call :: symb_call) :: state_data

  defdelegate [commands(mod), commands(mod, initial_state),
        more_commands(n, cmd_type), run_commands(mod, cmds),
        run_commands(mod, cmds, env), target_states(mod, from, data, call),
        state_names(history)], to: :proper_fsm
  defdelegate [command_names(cmds)], to: :proper_statem
end
