defmodule PropCheck.Test.LevelTest do
  use PropCheck
  use ExUnit.Case

  require Logger

  alias PropCheck.Test.Level
  # alias PropCheck.TargetedPBT

  #######################################################################
  # Generators
  #######################################################################

  def step(), do: oneof([:left, :right, :up, :down])

  def path_gen(), do: list(step())

  def path_gen_sa(), do: %{first: path_gen(), next: path_next()}

  @spec path_next() :: ([Level.step], any() -> PropCheck.BasicTypes.t)
  def path_next() do
    fn
      (prev_path, _temperature) when is_list(prev_path) ->
        let next_steps <- vector(20, step()), do:
          prev_path ++ next_steps
    end
  end

  #######################################################################
  # Properties
  #######################################################################

  def distance({x1, y1}, {x2, y2}), do:
    :math.sqrt(:math.pow(x1 - x2, 2) + :math.pow(y1 - y2, 2))

  # def prop_exit(level_data) ->
  #   Level = build_level(level_data),
  #   #{entrance := Entrance} = Level,
  #   ?FORALL(Path, path(),
  #           case follow_path(Entrance, Path, Level) of
  #             {exited, _} -> false;
  #             _ -> true
  #           end).

  # This is function taking the test data as parameter and applying
  # a classic property. The property tests for each path, at least
  # one connects the entrance with the exit. The construction uses
  # a negated logic using forall following the laws of logic quantors:
  #        exists x in xs suchthat p(x) == true
  # <==>   not (forall x in xs holds p(x) == false)
  #
  # Therefore, the property must be used together with `fails/1`,
  # i.e. everything is ok if the property fails and the counter example
  # is the path found from entrance to exit.
  def prop_exit(level_data) do
    level = Level.build_level(level_data)
    %{entrance: entrance} = level
    forall path <- path_gen() do
      case Level.follow_path(entrance, path, level) do
        {:exited, _} -> false
        _ -> true
      end
    end
  end

  # This property fails, this means that in every situation a path was found
  # ==> see docs of `prop_exit/1`
  property "Default PBT Level 0" do
    prop_exit(Level.level0())
    |> fails()
  end

  # This property does not fail. This means there PropCheck was not able to find
  # a path to the exit in every case. We need to search more cleverly =>
  # The case for Targeted PBT
  property "Default PBT Level 1" do
    prop_exit(Level.level1())
  end

  # prop_exit_targeted(LevelData) ->
  #   Level = build_level(LevelData),
  #   #{entrance := Entrance} = Level,
  #   #{exit := Exit} = Level,
  #   ?FORALL_SA(Path, ?TARGET(path_sa()),
  #              case follow_path(Entrance, Path, Level) of
  #                {exited, _Pos} -> false;
  #                Pos ->
  #                  case length(Path) > 500 of
  #                    true -> proper_sa:reset(), true;
  #                    _ ->
  #                      UV = distance(Pos, Exit),
  #                      ?MINIMIZE(UV),
  #                      true
  #                  end
  #              end).


  # This property uses `forall_targeted`, therefore the condition checked inside
  # the property is negated and it must be negated outside (see docs of `prop_exit/1` for
  # more details).
  # When using a proper-derived generator, we might have to search longer to find
  # a successful path. Therefore, we increase the amount of search_steps. For more complex
  # situations, e.g. for level 2, the size of the generated paths may become larger.
  property "Target PBT Level 1 with forall_targeted and proper-derived nf", [:verbose, search_steps: 2_0000] do
    level_data = Level.level1()
    level = Level.build_level(level_data)
    %{entrance: entrance} = level
    %{exit: exit_pos} = level

    forall_targeted path <- path_gen() do
      case Level.follow_path(entrance, path, level) do
        {:exited, _} -> false
        pos ->
          if length(path) > 500 do
            :proper_sa.reset()
            true
          else
            uv = distance(pos, exit_pos)
            minimize(uv)
            true
          end
      end
    end
    |> fails()
  end

  # prop_exit_targeted(LevelData) ->
  #   Level = build_level(LevelData),
  #   #{entrance := Entrance} = Level,
  #   #{exit := Exit} = Level,
  #   ?FORALL_TARGETED(Path, ?USERNF(path(), path_next()),
  #                    case follow_path(Entrance, Path, Level) of
  #                      {exited, _Pos} -> false;
  #                      Pos ->
  #                        case length(Path) > 2000 of
  #                          true -> proper_sa:reset(), true;
  #                          _ ->
  #                            UV = distance(Pos, Exit),
  #                            ?MINIMIZE(UV),
  #                            true
  #                        end
  #                    end).


  def prop_forall_targeted(level_data) do
    level = Level.build_level(level_data)
    %{entrance: entrance} = level
    %{exit: exit_pos} = level
    forall_targeted path <- user_nf(path_gen(), path_next()) do
      case Level.follow_path(entrance, path, level) do
        {:exited, _pos} -> false

        pos ->
          if length(path) > 2_000 do
            # reset the search because we assume that the path is
            # too long and we are caught in a local minimum.
            :proper_sa.reset()
            true
          else
            uv = distance(pos, exit_pos)
            minimize(uv)
            true
          end
      end
    end
  end

  # This property fails because the search is successful
  # In contrast to "Default PBT Level 1", where a pure
  # random search was not successful.
  # The logic is negative, therefore we expect that
  # the property fails.
  property "forall_targeted PBT Level 1", [:verbose] do
    level_data = Level.level1()
    prop_forall_targeted(level_data)
    |> fails()
  end

  # This test is flaky. It works perfectly on my machine but fails sometimes
  # on Travis CI. Currently, I have no idea how to properly handle this.
  @tag unstable_test: true
  property "forall_targeted PBT Level 2", [:verbose, search_steps: 3_000] do
    level_data = Level.level2()
    prop_forall_targeted(level_data)
    |> fails()
  end

  property "Exists Target PBT Level 1", [:verbose] do
    level_data = Level.level1()
    level = Level.build_level(level_data)
    %{entrance: entrance} = level
    %{exit: exit_pos} = level

    # Property: Proof that there exists a path from the entry of the labyrinth
    # to the exit.
    # There, generate random walks until you find the exit.
    exists path <- user_nf(path_gen(), path_next()) do
      # take the random walk `path` and look where it ends
      case Level.follow_path(entrance, path, level) do
        # we found the exit. => Stop the search. In PBT terms, the path is counterexample.
        {:exited, _pos} -> true

        # we are landed somewhere but did not find the exit.
        pos ->
          if length(path) > 2_000 do
            # reset the search because we assume that the path is
            # too long and we are caught in a local minimum.
            :proper_sa.reset()
            false
          else
            # measure the distance to exit and search for a new
            # variant of the walk which is closer the exit (=> minimize the distance)
            uv = distance(pos, exit_pos)
            minimize(uv)
            false
          end
      end
    end
  end


end
