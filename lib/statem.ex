defmodule PropCheck.StateM do

  defmacro __using__(_) do
    quote do
      @behaviour :proper_statem
      use PropCheck
      import PropCheck.StateM
    end
  end

  @callback initial_state() :: :proper_statem.symbolic_state
  @callback command(:proper_statem.symbolic_state) :: :proper_types.type
  @callback precondition(:proper_statem.symbolic_state, :proper_statem.symb_call) :: boolean
  @callback postcondition(:proper_statem.dynamic_state,
    :proper_types.symbolic_call, term) :: boolean
  @callback next_state(:proper_statem.symbolic_state | :proper_statem.dynamic_state,
    term, :proper_statem.symbolic_call) ::
    :proper_statem.symbolic_state | :proper_statem.dynamic_state

  defdelegate command_names(cmds),                   to: :proper_statem
  defdelegate commands(mod),                         to: :proper_statem
  defdelegate commands(mod, initial_state),          to: :proper_statem
  defdelegate more_commands(n, cmd_type),            to: :proper_statem
  defdelegate parallel_commands(mod),                to: :proper_statem
  defdelegate parallel_commands(mod, initial_state), to: :proper_statem
  defdelegate run_commands(mod, cmds),               to: :proper_statem
  defdelegate run_commands(mod, cmds, env),          to: :proper_statem
  defdelegate run_parallel_commands(mod, testcase),  to: :proper_statem
  defdelegate run_parallel_commands(mod, x2, env),   to: :proper_statem
  defdelegate state_after(mod, cmds),                to: :proper_statem
  defdelegate zip(l1, l2),                           to: :proper_statem

end
