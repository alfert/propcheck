defmodule PropCheck.Mix do

  @moduledoc false
  def counter_example_file() do
    Mix.Project.config()
    |> Keyword.get(:propcheck, [counter_examples: "_build/propcheck.ctex"])
    |> Keyword.get(:counter_examples)
  end
end

defmodule Mix.Tasks.Propcheck do

  @moduledoc """
  PropCheck runs property checking as part of ExUnit test and
  stores counter examples of failing properties in order to
  reapply them in the next test run.

  The file name for the counter examples can be configured in `mix.exs`
  in the project configuration as

      propcheck: [counter_example: "filename"]

  With `mix propcheck.inspect` you can inspect the found counter examples,
  with `mix propcheck.clean` the file is deleted afterwards.
  """

  defmodule Clean do
    use Mix.Task
    @moduledoc """
    Removes the counter example file of propcheck.
    """

    @shortdoc "Removes the counter example file of propcheck"

    @doc false
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

    @doc false
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
