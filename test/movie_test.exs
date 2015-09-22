defmodule PropCheck.Test.Movies do
  @moduledoc """
  This module is the Elixir version of the StateM-Tutorial
  from Proper (see http://proper.softlab.ntua.gr/Tutorials/PropEr_testing_of_generic_servers.html).
  """
	use PropCheck.Properties
  use PropCheck.StateM
  use ExUnit.Case

  alias PropCheck.Test.MovieServer

  #########################################################################
  ### The properties
  #########################################################################

  property_test "server works fine" do
      forall cmds in commands(__MODULE__) do
      trap_exit do
        MovieServer.start_link()
        r = run_commands(__MODULE__, cmds)
        {history, state, result} = r
        MovieServer.stop
        #IO.puts "Property finished. result is: #{inspect r}"
        when_fail(IO.puts("History: #{inspect history}\nState: #{inspect state}\nResult: #{inspect result}"),
          result == :ok)
      end
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
  @available_movies MovieServer.available_movies

  # movies that clients will ask to rent in the testcases
  # apart from the movies available, clients will also ask for titanic
  # and inception, in order to test how the server responds to these
  # requests
  @movie_titles (@available_movies |> Keyword.keys) ++ [:titanic, :inception]

  @doc "generator for name"
  def name(), do: elements @names

  @doc "generator for movies"
  def movie(), do: elements @movie_titles

  # The state of the state machine
  # first components holds the return value of create_account,
  # the second components holds the rented movies
  defstruct users: [],
    rented: HashDict.new

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
      oneof([{:call, MovieServer, :create_account, [name]},
           {:call, MovieServer, :ask_for_popcorn, []}])
  end
  def command(state = %__MODULE__{}) do
    oneof([{:call, MovieServer, :create_account, [name]},
           {:call, MovieServer, :ask_for_popcorn, []},
           {:call, MovieServer, :delete_account, [password(state)]},
           {:call, MovieServer, :rent_dvd, [password(state), movie]},
           {:call, MovieServer, :return_dvd, [password(state), movie]}
         ])
  end

  @doc "Initialize the model"
  def initial_state(), do: %__MODULE__{}

  @doc "The state machine entries"
  def next_state(s = %__MODULE__{users: users}, v, {:call, _, :create_account, [_name]}), do:
    %__MODULE__{s | users: [v | users]}
  def next_state(s = %__MODULE__{rented: rented, users: users}, _v, {:call, _, :delete_account, [password]}) do
		case (rented |> Dict.has_key? password) do
			false -> %__MODULE__{s | users: List.delete(users, password)}
			true  ->	s
		end
	end
  def next_state(s = %__MODULE__{rented: rented}, _v, {:call, _, :rent_dvd, [password, movie]}) do
    if is_available(s, movie) do
      %__MODULE__{s | rented: rented |> Dict.update(password, [movie], &([movie | &1]))}
    else
      s
    end
  end
  def next_state(s = %__MODULE__{rented: rented}, _v, {:call, _, :return_dvd, [password, movie]}), do:
    %__MODULE__{s | rented: Dict.update!(rented, password, &(&1 |> List.delete movie)) }
  def next_state(s, _v, {:call, _, :ask_for_popcorn, []}), do: s

  @doc "Don't return dvds, which are not rented"
  def precondition(state, {:call, _, :return_dvd, [password, movie]}) do
    state.rented |> Enum.member? {password, movie}
  end
  def precondition(_state, _call), do: true

  @doc "Postconditions ensure that the expected effect has taken place"
  def postcondition(%__MODULE__{users: users}, {:call, _, :create_account,[_name]}, result) do
    # the new user was formerly not available
    not (users |> Enum.member? result)
  end
  def postcondition(%__MODULE__{rented: rented}, {:call, _, :delete_account,[passwd]}, result) do
    # deletion does not work always
		case rented |> Dict.has_key?(passwd) do
    	false -> result == :account_deleted
			true ->  result == :return_movies_first
		end
  end
  def postcondition(state, {:call, _, :rent_dvd,[_passwd, movie]}, result) do
    # if the movie exists, then it must there, otherwise not
    if is_available(state, movie) do
      result |> Enum.member? movie
    else
      not (result |> Enum.member? movie)
    end
  end
	def postcondition(_state, {:call, _, :return_dvd, [_passwd, movie]}, result) do
	  not result |> Enum.member? movie
	end
  def postcondition(_state, {:call, _, :ask_for_popcorn, []}, result) do
    result == :bon_appetit
  end


  @doc "is the movie available?"
  def is_available(%__MODULE__{rented: rented}, movie) do
    max_av = @available_movies |> Keyword.get(movie, -1)
    (rented |> Enum.count fn({_, m}) -> m == movie end) < max_av
  end

end
