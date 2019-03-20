defmodule PropCheck.Test.Level do
  @moduledoc """
  Port of PropEr's example `level.erl` for Targeted PBT to Elixir.
  """

  @type pos() :: {non_neg_integer(), non_neg_integer()}
  @type brick() :: :wall | :exit | :entrance
  # We use a binary string, not a char list to be idiomatic in Elixir
  @type level_data() :: [String.t]
  @type level() :: %{
      optional(pos()) => brick(),
      exit: pos(),
      entrance: pos()
    }
  @type step() :: :left | :right | :up | :down

  #######################################################################
  # Level
  #######################################################################

  @spec level0() :: level_data()
  def level0, do:
    ["#########",
     "#X     E#",
     "#########"]

  @spec level1() :: level_data()
  def level1, do:
    ["######################################################################",
     "#                                                                    #",
     "#   E                                                                #",
     "#                                  #####                             #",
     "#                                  #####                             #",
     "#        #####                     #####        #####                #",
     "#        #####                                  #####                #",
     "#        #####                                  #####                #",
     "#                          #####                                     #",
     "#                          #####                                     #",
     "#                          #####                                     #",
     "#                                         #####          ##########  #",
     "#                                         #####          ##########  #",
     "#             #####                       #####          ##########  #",
     "#             #####                                                  #",
     "#             #####                                                  #",
     "#                                #####                               #",
     "#                                #####                               #",
     "#                                #####         #####                 #",
     "#                                              #####                 #",
     "#                                              #####                 #",
     "#                                                              X     #",
     "#                                                                    #",
     "######################################################################"]

  @spec level2() :: level_data()
  def level2, do:
    ["######################################################################",
     "#                                                                    #",
     "#    X                                                               #",
     "#                                                                    #",
     "#          #             ########   #####     ####   ########        #",
     "#          ###              ##      ##   #    ##  #     ##           #",
     "################            ##      #####     ####      ##           #",
     "#          ###              ##      ##        ##  #     ##           #",
     "#          #                ##      ##        ####      ##           #",
     "#                                                                    #",
     "#                                                                    #",
     "#                   #                                                #",
     "#                   #                                                #",
     "#                   #                #################################",
     "#                   #                                                #",
     "#                   #                                                #",
     "#                   #                                                #",
     "#                   ####################################             #",
     "#                                                                    #",
     "#                                                                    #",
     "################################                                     #",
     "#                                     E                              #",
     "#                                                                    #",
     "######################################################################"]

    @spec build_level(list(binary)) :: level()
    def build_level(data), do: build_level(data, %{}, 0)

    defp build_level([], acc, _), do: acc
    defp build_level([line | tail], acc, x) do
      new_acc = build_level_line(line, acc, x, 0)
      build_level(tail, new_acc, x + 1)
    end

    defp build_level_line("", acc, _, _), do: acc
    defp build_level_line(" " <> t, acc, x, y), do:
      build_level_line(t, acc, x, y + 1)
    defp build_level_line("#" <> t, acc, x, y) do
      m = Map.put(acc, {x, y}, :wall)
      build_level_line(t, m, x, y+1)
    end
    defp build_level_line("X" <> t, acc, x, y) do
      m = acc
      |> Map.put({x, y}, :exit)
      |> Map.put(:exit, {x, y})
      build_level_line(t, m, x, y+1)
    end
    defp build_level_line("E" <> t, acc, x, y) do
      m = acc
      |> Map.put({x, y}, :entrance)
      |> Map.put(:entrance, {x, y})
      build_level_line(t, m, x, y+1)
    end

    #######################################################################
    # Movement
    #######################################################################

    @spec do_step(pos(), step(), level()) :: pos()
    def do_step(pos = {x, y}, step, level) do
      next_pos = case step do
        :left -> {x, y - 1}
        :right -> {x, y + 1}
        :up -> {x - 1, y}
        :down -> {x + 1, y}
      end
      case level do
        %{^next_pos => :wall} -> pos
        _ -> next_pos
      end
    end

    @spec follow_path(pos(), [step()], level()) :: pos() | {:exited, pos()}
    def follow_path(start, path, level) do
      %{exit: exit_pos} = level
      Enum.reduce(path, start, fn
        (_, final = {:exited, _}) -> final
        (step, curr_pos) ->
            case do_step(curr_pos, step, level) do
              ^exit_pos -> {:exited, exit_pos}
              new_pos -> new_pos
            end
      end)
    end

end
