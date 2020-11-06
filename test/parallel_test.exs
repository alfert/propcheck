defmodule PropCheck.Test.Cache.DSL.Parallel do
  @moduledoc """
  Testing of the cache based on the EQC api and PropEr as backend, but this time in parallel approachc
  to find the data races in SequentialCache.
  """

  use ExUnit.Case, async: true
  use PropCheck, default_opts: &PropCheck.TestHelpers.config/0
  use PropCheck.StateM.ModelDSL

  alias PropCheck.Instrument
  alias PropCheck.Test.Cache
  alias PropCheck.YieldInstrumenter

  require Logger

  @cache_size 10

  setup_all do
    Instrument.instrument_module(Cache, YieldInstrumenter)
    # no update of a context
    :ok
  end

  @tag concurrency_test: true
  property "run the sequential cache concurrently", [:verbose] do
    forall cmds <- parallel_commands(__MODULE__, initial_state()) do
      Cache.start_link(@cache_size)
      r = run_parallel_commands(__MODULE__, cmds)
      {_history, _state, result} = r

      Cache.stop()

      (result == :ok)
      |> when_fail(print_report(r, cmds))
    end
  end

  ###########################
  # Developing the model

  # the state for testing (= the model)
  defstruct max: @cache_size, entries: [], count: 0

  # extract the list of state from the history
  def history_of_states(history) do
    history
    |> Enum.map(fn {state, _result} -> state end)
  end

  ###########################
  # Testing the command generators and such

  test "commands produces something" do
    cmd_gen = commands(__MODULE__) |> non_empty()
    size = 10
    {:ok, cmds} = produce(cmd_gen, size)

    assert is_list(cmds)

    first = hd(cmds)
    assert {:set, {:var, 1}, {:call, __MODULE__, _, _}} = first
  end

  ###########################
  # Generators for keys and values

  @doc """
  Keys are chosen from a set of reusable keys and some arbitrary keys.

  The generator for keys is designed to allow some keys to be repeated
  multiple time. By using a restricted set of keys (with the `integer/1 generator)
  along with a much wider one, the generator should help exercising any
  code related to key reuse or matching, but without losing the ability
  to 'fuzz' the system.
  """
  def key,
    do:
      oneof([
        integer(1, @cache_size),
        integer()
      ])

  @doc "our values are integers"
  def val, do: integer()

  ###################
  # the initial state of our model
  def initial_state, do: %__MODULE__{}

  ##################
  # The command weight distribution
  def command_gen(_state) do
    frequency([
      {1, {:find, [key()]}},
      {3, {:cache, [key(), val()]}},
      {1, {:flush, []}}
    ])
  end

  ###### Command: find

  defcommand :find do
    def impl(key), do: Cache.find(key)

    def post(%__MODULE__{entries: l}, [key], res) do
      case List.keyfind(l, key, 0, false) do
        false -> res == {:error, :not_found}
        {^key, val} -> res == {:ok, val}
      end
    end
  end

  defcommand :cache do
    # implement cache
    def impl(key, val), do: Cache.cache(key, val)
    def post(_model, _key, result), do: true == result
    # what is the next state?
    def next(s = %__MODULE__{entries: l, count: n, max: m}, [k, v], _res) do
      case List.keyfind(l, k, 0, false) do
        # When the cache is at capacity, the first element is dropped (tl(L))
        # before adding the new one at the end
        false when n == m -> update_entries(s, tl(l) ++ [{k, v}])
        # When the cache still has free place, the entry is added at the end,
        # and the counter incremented
        false when n < m -> update_entries(s, l ++ [{k, v}])
        # If the entry key is a duplicate, it replaces the old one without refreshing it
        {k, _} -> update_entries(s, List.keyreplace(l, k, 0, {k, v}))
      end
    end
  end

  defcommand :flush do
    # implement flush
    def impl, do: Cache.flush()
    # next state is: cache is empty
    def next(state, _args, _res) do
      update_entries(state, [])
    end

    # pre condition: do not call flush() twice
    def pre(%__MODULE__{count: c}, _args), do: c != 0
  end

  defp update_entries(s = %__MODULE__{}, l) do
    %__MODULE__{s | entries: l, count: Enum.count(l)}
  end
end
