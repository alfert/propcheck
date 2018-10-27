defmodule PropCheck.Test.LevelTest do
  use PropCheck
  use ExUnit.Case

  require Logger

  alias PropCheck.Test.Level
  alias PropCheck.TargetedPBT

  #######################################################################
  # Generators
  #######################################################################

  def step(), do: oneof([:left, :right, :up, :down])

  def path_gen(), do: list(step())

  def path_sa(), do: %{first: path_gen(), next: path_next()}

  @spec path_next() :: ([Level.step], any() -> PropCheck.BasicTypes.t)
  def path_next() do
    fn
      ({:"$used",  prev_path, _another_path}, _temperature) when is_list(prev_path) ->
       let next_steps <- vector(20, step()), do:
          prev_path ++ next_steps
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
  # ==> negated logic of the property
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


  property "Target PBT Level 1 with forall_sa", [:verbose] do
    level_data = Level.level1()
    level = Level.build_level(level_data)
    %{entrance: entrance} = level
    %{exit: exit_pos} = level
    forall_sa path <- target(path_sa()) do
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
      |> collect(length(path))
    end
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


  # This property fails because the search is successful
  # In contrast to "Default PBT Level 1", where a pure
  # random search was not successful.
  # The logic is negative, therefore we expect that
  # the property fails.
  property "forall_targeted PBT Level 1", [:verbose] do
    level_data = Level.level1()
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
    |> fails()
  end

  property "Exists Target PBT Level 1", [:verbose] do
    level_data = Level.level0()
    level = Level.build_level(level_data)
    %{entrance: entrance} = level
    %{exit: exit_pos} = level
    exists path <- path_sa() do
      case Level.follow_path(entrance, path, level) do
        {:exited, _} -> false
        pos ->
          uv = distance(pos, exit_pos)
          minimize(uv)
          true
      end
    end
  end


end