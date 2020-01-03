defmodule PropCheck.Test.MovieServer do
  @moduledoc false

  use GenServer

  @movies [{:mary_poppins, 3}, {:finding_nemo, 2}, {:despicable_me, 3},
      {:toy_story, 5}, {:the_lion_king, 2}, {:peter_pan, 1}]

  @type name :: atom
  @type movie :: atom
  @type password :: pos_integer

  defstruct users: nil,
    movies: nil,
    next_pass: 0,
    popcorn_failure: false

  def start_link, do: start_link(will_fail: false)
  def start_link(args = [will_fail: true]), do:
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  def start_link(args = [will_fail: false]), do:
    GenServer.start_link(__MODULE__, args, name: __MODULE__)

  def stop do
    ref = Process.monitor(__MODULE__)
    GenServer.call(__MODULE__, :stop)
    receive do
      {:DOWN, ^ref, :process, _object, _reason} -> :ok
    end
  end

  @spec create_account(name) :: password
  def create_account(name), do: GenServer.call(__MODULE__, {:new_account, name})

  @spec delete_account(password) :: :not_a_client | :account_deleted | :return_movies_first
  def delete_account(password), do:
    GenServer.call(__MODULE__, {:delete_account, password})

  @spec rent_dvd(password, movie) :: [movie] | :not_a_client
  def rent_dvd(password, movie), do: GenServer.call(__MODULE__, {:rent, password, movie})

  @spec return_dvd(password, movie) :: [movie()] | :not_a_client
  def return_dvd(password, movie), do:
    GenServer.call(__MODULE__, {:return, password, movie})

  @spec ask_for_popcorn() :: :bon_appetit
  def ask_for_popcorn, do: GenServer.call(__MODULE__, :popcorn)

  def available_movies, do: @movies

  ##########################################################

  def init([will_fail: will_fail]) when is_boolean(will_fail) do
    tid = :ets.new(:movies, [])
    :ets.insert(tid, @movies)
    {:ok, %__MODULE__{users: :ets.new(:users, []),
      movies: tid, next_pass: 1, popcorn_failure: will_fail}}
  end

  def terminate(_reason, %__MODULE__{movies: m, users: u}) do
    :ets.delete(m)
    :ets.delete(u)
    :ok
  end

  defp popcorn_answer(%__MODULE__{popcorn_failure: false}), do: :bon_appetit
  defp popcorn_answer(%__MODULE__{popcorn_failure: true}), do:
    Enum.random([:bon_appetit, :bon_appetit, :bon_appetit,
      :bon_appetit, :bon_appetit, :bon_appetit,
      :bon_appetit, :bon_appetit, :bon_appetit,
      :fuck_off])

  def handle_call(:popcorn, _from, s),
    do: {:reply, popcorn_answer(s), s}
  def handle_call(:stop, _from, s), do: {:stop, :normal, :stopped, s}
  def handle_call({:new_account, name}, _from, s = %__MODULE__{next_pass: p, users: u}) do
    :ets.insert(u, {p, name, []})
    {:reply, p, %__MODULE__{s | next_pass: p + 1}}
  end
  def handle_call({:delete_account, p}, _from, s = %__MODULE__{users: u}) do
    reply = case :ets.lookup(u, p) do
      []          -> :not_a_client
      [{_, _, []}]  -> :ets.delete(u, p)
                     :account_deleted
      [{_, _, _}] -> :return_movies_first
    end
    {:reply, reply, s}
  end
  def handle_call({:rent, pass, movie}, _from, s = %__MODULE__{users: u, movies: m}) do
    reply = case :ets.lookup(u, pass) do
      []             -> :not_a_client
      [{_, _, rented}] -> case :ets.lookup(m, movie)  do
        [] -> rented
        [{_, 0}] -> rented
        [{_, n}] ->
          new_rented = [movie | rented]
          :ets.update_element(u, pass, {3, new_rented})
          :ets.update_element(m, movie, {2, n - 1})
          new_rented
      end
    end
    {:reply, reply, s}
  end
  def handle_call({:return, pass, movie}, _from, s = %__MODULE__{users: u, movies: m}) do
    reply = case :ets.lookup(u, pass) do
      []             -> :not_a_client
      [{_, _, rented}] -> case :ets.lookup(m, movie) do
        [] -> rented
        [{_, n}] ->
          new_rented = rented |> List.delete(movie)
          :ets.update_element(u, pass, {3, new_rented})
          :ets.update_element(m, movie, {2, n + 1})
          new_rented
      end
    end
    {:reply, reply, s}
  end

end
