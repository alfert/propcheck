defmodule PropCheck.CounterStrike do
  @moduledoc """
  A GenServer storing and retrieving counter examples. It helps to focus on
  resolving failing properties with the same counterexamples until they are
  resolved.

  To be able to do a fast look of an existing counter example, we use
  ETS store. Every new recorded counterexample from a failing property
  is written to a DETS, store it properly when the Erlang system shuts down.
  The ETS table is filled from DETS during startup and remains immutable
  afterwards.
  """

  use GenServer

  defstruct [ets: nil, dets: nil]

  @ets_name :old_CEs
  @dets_name :new_CEs

  def start_link(filename \\ 'propcheck.dets')
  def start_link(filename) when is_binary(filename), do: start_link(String.to_charlist(filename))
  def start_link(filename) when is_list(filename) do
    GenServer.start_link(__MODULE__, [filename], name: __MODULE__)
  end

  def stop() do
    GenServer.stop(__MODULE__, :normal)
  end

  @doc """
  Stores a new counter examples into the DETS
  """
  def add_counter_example(mfa, counterexample) do
    GenServer.call(__MODULE__, {:add, mfa, counterexample})
  end

  @doc """
  Retrieves the counter example for the given property. Returns
  `:none` if there are now counterexamples at all, `:others` if
  only other properties have counter examples and `{:ok, counter_example}`
  if a counter example exists for the given property.
  """
  @spec counter_example(mfa) :: :none | :others | {:ok, any}
  def counter_example(mfa) do
    if :ets.first(@ets_name) == :"$end_of_table" do
      :none
    else
      case :ets.lookup(@ets_name, mfa) do
        [] -> :others
        [{^mfa, counter_example}] -> {:ok, counter_example}
      end
    end
  end

  @doc """
  Loads the counter examples from DETS file and stores them
  into the ETS. Afterwards the DETS is emptied to prepare for
  storing new counter examples.
  """
  @spec load_existing_counter_examples(:ets.tid, :dets.tid) :: boolean
  def load_existing_counter_examples(ets, dets) do
    with true <- :ets.from_dets(ets, dets) do
      :ok = :dets.delete_all_objects(dets)
      true
    end
  end

  def init([filename]) do
    {:ok, new_ces} = :dets.open_file(:new_CEs, [file: filename, auto_save: 500])
    old_ces = :ets.new(@ets_name, [:named_table, :protected])
    @ets_name = old_ces
    true = load_existing_counter_examples(old_ces, new_ces)
    {:ok, %__MODULE__{ets: old_ces, dets: new_ces}}
  end

  def handle_call({:add, mfa, counter_example}, _from, state) do
    true = :dets.insert_new(@dets_name, {mfa, counter_example})
    {:reply, :ok, state}
  end

  def terminate(_reason, _state) do
    # IO.puts "Terminating Counter Strike"
    :dets.close(@dets_name)
  end
end
