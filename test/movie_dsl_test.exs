defmodule PropCheck.Test.MoviesDSL do
  @moduledoc """
  This module is the Elixir version of the StateM-Tutorial
  from Proper (see http://proper.softlab.ntua.gr/Tutorials/PropEr_testing_of_generic_servers.html).
  """
  use PropCheck, default_opts: &PropCheck.TestHelpers.config/0
  use PropCheck.StateM.ModelDSL
  use ExUnit.Case
  # import PropCheck.TestHelpers, except: [config: 0]
  require Logger

  alias PropCheck.Test.MovieServer

  @moduletag capture_log: true

  #########################################################################
  ### The properties
  #########################################################################

  property "server works fine" do
    forall cmds <- commands(__MODULE__) do
      trap_exit do
        {:ok, _pid} = MovieServer.start_link()
        r = run_commands(__MODULE__, cmds)
        {_history, _state, result} = r
        MovieServer.stop

        (result == :ok)
        |> when_fail(print_report(r, cmds))
        # |> aggregate(command_names cmds)
      end
    end
  end

  @tag will_fail: true
  property "server has illegal states" do
    forall cmds <- commands(__MODULE__) do
      trap_exit do
        {:ok, _pid} = MovieServer.start_link(will_fail: true)
        r = run_commands(__MODULE__, cmds)
        {_history, _state, result} = r
        MovieServer.stop

        (result == :ok)
        |> when_fail(print_report(r, cmds))
        # |> aggregate(command_names cmds)
      end
    end
  end
  #########################################################################
  ### Model state
  #########################################################################
  # `users` holds the return value of create_account,
  # `rented` holds the rented movies
  @type t :: %__MODULE__{users: [atom], rented: %{atom => [atom]}}
  defstruct users: [], rented: %{}

  @doc "Initialize the model"
  def initial_state, do: %__MODULE__{}

  #########################################################################
  ### Test local preconditions, helpers and the like
  #########################################################################

  test "user_movie_pairs works with symb vars" do
    s = %__MODULE__{rented: %{{:var, 1} => [:mary_poppins]}, users: [{:var, 1}]}
    Logger.debug(fn -> "test u_m_p: #{inspect s}" end)
    assert [{{:var, 1}, :mary_poppins}] == user_movie_pairs(s)
  end

  #########################################################################
  ### Commands generator
  #########################################################################
  def command_gen(%__MODULE__{users: []}) do
    frequency([
      {1, {:create_account, [name()]}},
      {1, {:ask_for_popcorn, []}},
    ])
  end
  def command_gen(s) do
    std_commands = [
      {1, {:create_account, [name()]}},
      {1, {:ask_for_popcorn, []}},
      {1, {:delete_account, [password(s)]}},
      {1, {:rent_dvd, [password(s), movie()]}},
    ]

    calls = if some_movies_rented?(s) do
      args = let {pass, movie} <- oneof(user_movie_pairs(s)), do: [pass, movie]
      [{5, {:return_dvd, args}} | std_commands]
    else
      std_commands
    end

    frequency(calls)
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

  # movies that clients will ask to rent in the test cases
  # apart from the movies available, clients will also ask for titanic
  # and inception, in order to test how the server responds to these
  # requests
  @movie_titles Keyword.keys(@available_movies) ++ [:titanic, :inception]

  @doc "generator for name"
  def name, do: oneof @names

  @doc "generator for movies"
  def movie, do: oneof @movie_titles

  @doc """
  Generate only valid passwords, i.e those from existing users.
  However, this generator fails if no users are available,
  therefore this has to be considered in designing the
  state machine.
  """
  def password(%__MODULE__{users: []}) do
    raise "No users available, what a mess!"
  end
  def password(%__MODULE__{users: users}) do
    oneof users
  end

  #########################################################################
  ### command definitions
  #########################################################################

  defcommand :create_account do
    def impl(name) do
      # Logger.info "Create account #{inspect name}"
      MovieServer.create_account(name)
    end
    def next(s = %__MODULE__{users: users}, _name, password) do
      # Logger.info "created account for password #{inspect password}"
      %__MODULE__{s | users: [password | users]}
    end
    def post(%__MODULE__{users: users}, _name, password), do:
      # the new user was not in the user db already
      not Enum.member?(users, password)
  end

  defcommand :delete_account do
    def impl(passwd) do
      # Logger.info "Delete account #{inspect passwd}"
      MovieServer.delete_account(passwd)
    end
    def pre(state, [passwd]), do: user_exists?(state, passwd)
    def next(s = %__MODULE__{rented: rented, users: users}, [passwd], _res) do
      case Map.get(rented, passwd, []) do
        []   -> %__MODULE__{
                  users: List.delete(users, passwd),
                  rented: Map.delete(rented, passwd)
                }
        _any -> s
      end
    end
    def post(%__MODULE__{rented: rented}, [passwd], result) do
      # Logger.debug "post delete: passwd=#{inspect passwd}, result=#{inspect result}"
      case Map.get(rented, passwd, []) do
        []   -> result == :account_deleted
        _any -> result == :return_movies_first
      end
    end
  end

  defcommand :ask_for_popcorn do
    def impl, do: MovieServer.ask_for_popcorn()
    def post(_state, [], result), do: result == :bon_appetit
  end

  defcommand :rent_dvd do
    def args(state), do: fixed_list([password(state), movie()])
    def impl(passwd, movie), do: MovieServer.rent_dvd(passwd, movie)
    def pre(state, [password, movie]) do
      user_exists?(state, password) and
        not movie_rented?(state, password, movie)
    end
    def next(s = %__MODULE__{rented: rented}, [passwd, movie], _res) do
      case is_available(s, movie) do
        true  -> %__MODULE__{s | rented: Map.update(rented, passwd, [movie], &([movie | &1]))}
        false -> s
      end
    end
    def post(state, [_passwd, movie], rented_movies) do
      case is_available(state, movie) do
        true  -> Enum.member?(rented_movies, movie)
        false -> not Enum.member?(rented_movies, movie)
      end
    end
  end

  defcommand :return_dvd do
    def impl(passwd, movie), do: MovieServer.return_dvd(passwd, movie)

    @doc "Don't return movies, which are not rented"
    def pre(state, [passwd, movie]), do: movie_rented?(state, passwd, movie)
    def next(s = %__MODULE__{rented: rented}, [passwd, movie], _res) do
      %__MODULE__{s | rented: Map.update!(rented, passwd, &List.delete(&1, movie))}
    end
    def post(_state, [_passwd, movie], result) do
      not Enum.member?(result, movie)
    end
  end

  @doc "is the movie available?"
  def is_available(%__MODULE__{rented: rented}, movie) do
    max_av = Keyword.get(@available_movies, movie, 0)

    available = max_av - (rented
      |> Map.values()
      |> List.flatten()
      |> Stream.filter(&(&1 == movie))
      |> Enum.count()
    )

    available > 0
  end

  # are some movies rented?
  @spec some_movies_rented?(t) :: boolean
  defp some_movies_rented?(%__MODULE__{rented: rented}) do
    result = rented
    |> Map.to_list()
    |> Enum.flat_map(fn {_k, v} -> v end)
    |> Enum.count() > 0
    # Logger.debug "some_movies_rented?: #{inspect rented} = #{inspect result}"
    result
  end

  @spec user_movie_pairs(t) :: [{integer | DSL.symbolic_var, atom}]
  defp user_movie_pairs(%__MODULE__{rented: rented}) do
    rented
    |> Map.to_list()
    |> Enum.flat_map(fn {passwd, movies} ->
      Enum.map(movies, fn m -> {passwd, m} end)
    end)
  end

  defp user_exists?(%__MODULE__{users: users}, passwd) do
    Enum.member?(users, passwd)
  end

  defp movie_rented?(%__MODULE__{rented: rented}, passwd, movie) do
    rented
    |> Map.get(passwd, [])
    |> Enum.member?(movie)
  end

end
