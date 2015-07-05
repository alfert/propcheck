defmodule PropCheck.Result do
  use GenServer

  defstruct tests: [], errors: [], current: nil

  def start_link do
    :gen_server.start_link({ :local, __MODULE__ }, __MODULE__, [], [])
  end
  def stop do
    try do
      :gen_server.call(__MODULE__, :stop)
    catch
      _ -> :ok
    end
  end
  def status do
    :gen_server.call(__MODULE__, :status)
  end

  def message(fmt, args) do
    :gen_server.call(__MODULE__, {:message, fmt, args})
  end

 def init(_args) do
    { :ok, %__MODULE__{} }
  end

  def handle_call({:message, fmt, args}, _from, state) do
    if :lists.prefix('Error', fmt) do
       state = %__MODULE__{state | errors: [{state.current, {fmt, args}}|state.errors]}
    end
    if :lists.prefix('Failed', fmt) do
       # state = state.errors([{state.current, {fmt, args}}|state.errors])
       state = %__MODULE__{state | errors: [{state.current, {fmt, args}}|state.errors]}
    end
    if :lists.prefix('Testing', fmt) do
       # state = state.tests([args|state.tests])
       # state = state.current(args)
       state = %__MODULE__{state | tests: [args | state.tests], current: args}
    end
    { :reply, :ok, state }
  end

  def handle_call(:status, _from, state) do
    { :reply, {state.tests, state.errors} , state }
  end
  def handle_call(:stop, _from, state) do
    { :stop, :normal, :ok, state }
  end
end
