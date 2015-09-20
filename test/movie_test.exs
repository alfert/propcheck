defmodule PropCheck.Test.Movies do
  @moduledoc """
  This module is the Elixir version of the StateM-Tutorial
  from Proper (see http://proper.softlab.ntua.gr/Tutorials/PropEr_testing_of_generic_servers.html).
  """
	use PropCheck.Properties
  use PropCheck.StateM
  use ExUnit.Case

  @mod PropCheck.Test.MovieServer
  #########################################################################
  ### The properties
  #########################################################################

  property_test "server works fine" do
    forall cmds in commands(__MODULE__) do
      @mod.start_link()
      {_, _, result} = run_commands(__MODULE__, cmds)
      @mod.stop()
      result == :ok
    end
  end

  #########################################################################
  ### Value generators
  #########################################################################

  # people visiting the dvd-club
  @names [:bob, :alice, :john, :mary, :ben]

  # a property list of the available movies,
  # each pair in the list consists of a movie name and the number of
  # existing copies of this movie
  @available_movies @mod.available_movies

  # movies that clients will ask to rent in the testcases
  # apart from the movies available, clients will also ask for titanic
  # and inception, in order to test how the server responds to these
  # requests
  @movie_titles @available_movies ++ [:titanic, :inception]

  @doc "generator for name"
  def name(), do: elements @names

  @doc "generator for movies"
  def movie(), do: elements @movie_titles

  # The state of the state machine
  # first components holds the return value of create_account,
  # the second components holds the rented movies
  defstruct users: [],
    rented: []

  @doc """
  Generate only valid passwords, i.e those from existing users.
  However, this generator fails if no users are available,
  therefore this has to be considered in designing the
  state machine.
  """
  def password(%__MODULE__{users: users}) do
    elements users
  end

  #########################################################################
  #########################################################################
  ### Command generators, pre- and postcondition
  #########################################################################

  @doc "Set of all allowed commands"
  def command(_state = %__MODULE__{users: []}) do
      oneof([{:call, @mod, :create_account, [name]},
           {:call, @mod, :ask_for_popcorn, []}])
  end
  def command(state = %__MODULE__{}) do
    oneof([{:call, @mod, :create_account, [name]},
           {:call, @mod, :ask_for_popcorn, []},
           {:call, @mod, :delete_account, [password(state)]},
           {:call, @mod, :rent_dvd, [password(state), movie]},
           {:call, @mod, :return_dvd, [password(state), movie]}
         ])
  end

  @doc "Initialize the model"
  def initial_state(), do: %__MODULE__{}

  @doc "The state machine entries"
  def next_state(s = %__MODULE__{users: users}, v, {:call, _, :create_account, [_name]}), do:
    %__MODULE__{s | users: [v | users]}
  def next_state(s = %__MODULE__{users: users}, _v, {:call, _, :delete_account, [password]}), do:
    %__MODULE__{s | users: List.delete(users, password)}
  def next_state(s = %__MODULE__{rented: rented}, _v, {:call, _, :rent_dvd, [password, movie]}) do
    if is_available(s, movie) do
      %__MODULE__{s | rented: [{password, movie} | rented]}
    else
      s
    end
  end
  def next_state(s = %__MODULE__{rented: rented}, _v, {:call, _, :return_dvd, [password, movie]}) do
     %__MODULE__{s | rented: List.delete(rented, {password, movie})}
  end
  def next_state(s, _v, {:call, _, :ask_for_popcorn, []}), do: s

  @doc "Currently no preconditions"
  def precondition(_state, _call), do: true

  @doc "Postconditions ensure that the expected effect has taken place"
  def postcondition(%__MODULE__{users: users}, {:call, _, :create_account,[_name]}, result) do
    # the new user was formerly not available
    not (users |> Enum.member? result)
  end
  def postcondition(_state, {:call, _, :delete_account,[_passwd]}, result) do
    # deletion always works
    result == :account_deleted
  end
  def postcondition(state, {:call, _, :rent_dvd,[_passwd, movie]}, result) do
    # if the movie exists, then it must there, otherwise not
    if is_available(state, movie) do
      result |> Enum.member? movie
    else
      not (result |> Enum.member? movie)
    end
  end
  def postcondition(_state, {:call, _, :ask_for_popcorn, []}, result) do
    result == :bon_appetit
  end


  @doc "is the movie available?"
  def is_available(%__MODULE__{rented: rented}, movie) do
    max_av = @available_movies |> Keyword.get(movie, -1)
    (rented |> Enum.count fn(_, m) -> m == movie end) < max_av
  end

end
