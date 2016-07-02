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

  defdelegate commands(mod),                        to: :proper_fsm
  defdelegate commands(mod, initial_state),         to: :proper_fsm
  defdelegate more_commands(n, cmd_type),           to: :proper_statem
  defdelegate run_commands(mod, cmds),              to: :proper_fsm
  defdelegate run_commands(mod, cmds, env),         to: :proper_fsm
  defdelegate target_states(mod, from, data, call), to: :proper_fsm
  defdelegate state_names(history),                 to: :proper_fsm
  defdelegate command_names(cmds),                  to: :proper_statem
end
