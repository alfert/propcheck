defmodule PropCheck.Mix do

  def counter_example_file() do
    Mix.Project.config()
    |> Keyword.get(:propcheck, [counter_examples: "counterexamples.dets"])
    |> Keyword.get(:counter_examples)
  end
end
defmodule Mix.Tasks.Propcheck do
  defmodule Clean do
    use Mix.Task
    @moduledoc """
    Removes the counter example file of propcheck.
    """

    @shortdoc "Removes the counter example file of propcheck"

    def run(_args) do
      File.rm(PropCheck.Mix.counter_example_file())
    end
  end

  defmodule Inspect do
    use Mix.Task
    @moduledoc """
    Inspects all counter examples.
    """

    @shortdoc "Inspects and prints all counter examples."

    def run(_args) do
      filename = PropCheck.Mix.counter_example_file() |> String.to_charlist()
      case :dets.open_file(filename) do
        {:ok, ctx} ->
          fn {{m, f, _a}, counter_example}, counter ->
            prop = "#{m}.#{f}()"
            Mix.Shell.IO.info "##{counter}: Property #{prop}: #{inspect counter_example}"
            counter + 1
          end
          |> :dets.foldl(1, ctx)

        _ -> Mix.Shell.IO.error("Could not open counter examples file #{filename}")
      end
    end

  end

end
