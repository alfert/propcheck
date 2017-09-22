defmodule PropCheck.Mix do

  def counter_example_file() do
    "counterexamples.dets"
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
      {:ok, ctx} = :dets.open_file(filename)
      fn {{m,f,a}, counter_example}, counter ->
        prop = "#{m}.#{f}()"
        Mix.Shell.IO.info "##{counter}: Property #{prop}: #{inspect counter_example}"
        counter + 1
      end
      |> :dets.foldl(1, ctx)
    end

  end

end
