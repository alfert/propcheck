defmodule PropCheck.Result do
  @moduledoc false

  # A GenServer managing the results of test runs

  use GenServer

  defstruct tests: [], errors: [], current: nil
  @type t :: %__MODULE__{tests: [any], errors: [any], current: nil | atom}

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

 @spec init(any) :: {:ok, t}
 def init(_args) do
    { :ok, %__MODULE__{} }
  end

  @spec handle_call({:message, any, any}, {pid, any}, t) :: {:reply, :ok, t}
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
