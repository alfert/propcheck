defmodule PropCheck.StateM do

  defmacro __using__(_) do
    quote do
      @behaviour :proper_statem
      use PropCheck.Properties
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

  defdelegate [command_names(cmds), commands(mod), commands(mod, initial_state),
    more_commands(n, cmd_type), parallel_commands(mod),
    parallel_commands(mod, initial_state), run_commands(mod, cmds),
    run_commands(mod, cmds, env), run_parallel_commands(mod, testcase),
    run_parallel_commands(mod, x2, env), state_after(mod, cmds),
    zip(l1, l2)], to: :proper_statem

end
