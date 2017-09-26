defmodule PropCheck.CounterStrike do

  # A GenServer storing and retrieving counter examples. It helps to focus on
  # resolving failing properties with the same counterexamples until they are
  # resolved.
  #
  # To be able to do a fast look of an existing counter example, we use
  # ETS store. Every new recorded counterexample from a failing property
  # is written to a DETS, store it properly when the Erlang system shuts down.
  # The ETS table is filled from DETS during startup and remains immutable
  # afterwards.

  @moduledoc false

  use GenServer
  require Logger

  defstruct [counter_examples: %{}, dets: nil]

  def start_link(filename \\ 'propcheck.dets', opts \\[])
  def start_link(filename, opts) when is_binary(filename), do: start_link(String.to_charlist(filename), opts)
  def start_link(filename, opts) when is_list(filename) do
    # Logger.info "Filename: #{filename}, options: #{inspect opts}"
    GenServer.start_link(__MODULE__, [filename], opts)
  end

  def stop(pid \\ __MODULE__) do
    GenServer.stop(pid, :normal)
  end

  @doc """
  Stores a new counter examples into the DETS
  """
  def add_counter_example(pid \\ __MODULE__, mfa, counterexample) do
    GenServer.call(pid, {:add, mfa, counterexample})
  end

  @doc """
  Retrieves the counter example for the given property.

  Returns
  `:none` if there are no counterexamples at all, `:others` if
  only other properties have counter examples and `{:ok, counter_example}`
  if a counter example exists for the given property.
  """
  @spec counter_example(GenServer.server, mfa) :: :none | :others | {:ok, any}
  def counter_example(pid \\ __MODULE__, mfa) do
    GenServer.call(pid, {:counter_example, mfa})
  end

  def init([filename]) do
    dets_name = String.to_atom("#{inspect self()}")
    {:ok, new_ces} = :dets.open_file(dets_name, [file: filename, auto_save: 500])
    counter_examples = load_existing_counter_examples(%{}, new_ces)
    {:ok, %__MODULE__{counter_examples: counter_examples, dets: new_ces}}
  end

  def handle_call({:add, mfa, counter_example}, _from, state) do
    # Logger.debug "add for #{inspect mfa} the example: #{inspect counter_example}"
    true = :dets.insert_new(state.dets, {mfa, counter_example})
    :ok = :dets.sync(state.dets)
    {:reply, :ok, state}
  end
  def handle_call({:counter_example, mfa}, _from, state) do
    {:reply, check_counter_example(state.counter_examples, mfa), state}
  end

  defp check_counter_example(counter_examples, mfa) do
    # Logger.debug "#{inspect self()}: Asked for mfa #{inspect mfa} in #{inspect counter_examples}"
    if (Enum.count(counter_examples) == 0) do
      :none
    else
      case Map.fetch(counter_examples, mfa) do
        :error -> :others
        found -> found
      end
    end
  end

  # Loads the counter examples from DETS file and stores them
  # into the map. Afterwards the DETS is emptied to prepare for
  # storing new counter examples.
  @spec load_existing_counter_examples(%{mfa => any}, :dets.tid) :: %{mfa => any}
  defp load_existing_counter_examples(ce, dets) do
    # Logger.debug "Loading existing examples from #{inspect dets}"
    new_ce = :dets.foldl(fn {mfa, example}, ces ->
      Map.put_new(ces, mfa, example) end, ce, dets)
    # Logger.debug "Found examples: #{inspect new_ce}"
    :ok = :dets.delete_all_objects(dets)
    :ok = :dets.sync(dets)
    new_ce
  end

  def terminate(_reason, state) do
    # IO.puts "Terminating Counter Strike"
    :dets.close(state.dets)
  end
end
