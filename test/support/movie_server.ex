defmodule PropCheck.Test.MovieServer do

  use GenServer

  @movies [{:mary_poppins,3}, {:finding_nemo,2}, {:despicable_me,3},
		 {:toy_story,5}, {:the_lion_king,2}, {:peter_pan,1}]

  @type name :: atom
  @type movie :: atom
  @type password :: pos_integer

  defstruct users: nil,
    movies: nil,
    next_pass: 0

  def start_link(), do:
    GenServer.start_link(__MODULE__, [], name: {:local, __MODULE__})

  def stop(), do: GenServer.call(__MODULE__, :stop)

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
  def ask_for_popcorn(), do: GenServer.call(__MODULE__, :popcorn)

  def available_movies(), do: @movies

  ##########################################################

  def init([]) do
    tid = :ets.new(:movies, [])
    :ets.insert(tid, @movies)
    {:ok, %__MODULE__{users: :ets.new(:users, []),
      movies: tid, next_pass: 1}}
  end

  def terminate(_reason, %__MODULE__{movies: m, users: u}) do
    :ets.delete(m)
    :ets.delete(u)
    :ok
  end

  def handle_call(:popcorn, _from, s), do: {:reply, :bon_appetit, s}
  def handle_call(:stop, _from, s), do: {:stop, :normal, :stopped, s}
  def handle_call({:new_account, name}, _from, %__MODULE__{next_pass: p, users: u} = s) do
    :ets.insert(u, {p, name})
    {:reply, p, %__MODULE__{s | next_pass: p+1}}
  end
  def handle_call({:delete_account, p}, _from, %__MODULE__{users: u} = s) do
    reply = case :ets.lookup(u, p) do
      []          -> :not_a_client
      [{_,_,[]}]  -> :ets.delete(u, p)
                     :deleted
      [{_, _, _}] -> :return_movies_first
    end
    {:reply, reply, s}
  end
  def handle_call({:rent, pass, movie}, _from, %__MODULE__{users: u, movies: m}=s) do
    reply = case :ets.lookup(u, pass) do
      []             -> :not_a_client
      [{_,_,rented}] -> case :ets.lookup(m, movie)  do
        [] -> rented
        [{_, 0}] -> rented
        [{_, n}] ->
          new_rented = [movie | rented]
          :ets.update_element(u, pass, {3, new_rented})
          :ets.update_element(m, movie, {2, n-1})
          new_rented
      end
    end
    {:reply, reply, s}
  end
  def handle_call({:return, pass, movie}, _from, %__MODULE__{users: u, movies: m}=s) do
    reply = case :ets.lookup(u, pass) do
      []             -> :not_a_client
      [{_,_,rented}] -> case :ets.lookup(m, movie) do
        [] -> rented
        [{_, n}] ->
          new_rented = rented |> List.delete(movie)
          :ets.update_element(u, pass, {3,new_rented})
			    :ets.update_element(m, movie, {2, n+1})
          new_rented
      end
    end
    {:reply, reply, s}
  end

end
