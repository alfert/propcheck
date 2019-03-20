defmodule PropCheck.Test.Cache do
  @moduledoc """
  Implements the basic sequential cache from
  http://propertesting.com/book_stateful_properties.html
  """

  use GenServer
  require Logger

  @cache_name __MODULE__

  def start_link(n) do
    GenServer.start_link(__MODULE__, [n], name: @cache_name)
  end

  def stop, do: GenServer.stop(__MODULE__)

  @doc """
  Finding keys is done through scanning an ETS table with `:ets.match/2`
  """
  def find(key) do
    case :ets.match(@cache_name, {:_, {key, :"$1"}}) do
        [[val]] -> {:ok, val}
        [] -> {:error, :not_found}
    end
  end

  @doc """
  Caching overwrites duplicates. If the the table is full, overwrite
  from the start.
  """
  def cache(key,  val) do
    # Logger.debug "Cache.cache(#{inspect key}, #{inspect val})"
    case :ets.match(@cache_name, {:"$1", {key, :_}}) do # find dupes
        [[n]] ->
            # Logger.debug "Cache: override as pos #{n}"
            :ets.insert(@cache_name, {n, {key, val}}) # overwrite dupe
        [] -> insert(key, val)
    end
    # Logger.debug "Updated Cache is: #{inspect dump()}"
  end

  defp insert(key, val) do
    [{:count, current, max}] = :ets.lookup(@cache_name, :count)
    # Logger.debug "Current: #{current}, Max: #{inspect max}"
    if current < max do
      # Logger.debug "Cache: Incrementally add at pos #{current + 1}"
      :ets.insert(@cache_name, [{current+1, {key, val}},
                         {:count, current + 1, max}])
    else
      # table is full, override from the beginning
      #  Logger.debug "Cache is full, override position 1"
      :ets.insert(@cache_name, [{1, {key, val}}, {:count, 1, max}])
    end
  end

  @doc """
  The cache gets flushed by removing all the entries and resetting its counters
  """
  def flush do
    [{:count, _, max}] = :ets.lookup(@cache_name, :count)
    :ets.delete_all_objects(@cache_name)
    :ets.insert(@cache_name, {:count, 0, max})
  end

  def dump do
    :ets.tab2list(@cache_name)
    |> Enum.sort_by(fn
      {index, {_k, _v}} -> index
      {:count, _, _} -> :count
    end)
  end

  def init([n]) when is_integer(n) and n > 0 do
    :ets.new(@cache_name, [:public, :named_table])
    :ets.insert(@cache_name, {:count, 0, n})
    {:ok, :nostate}
  end

end
