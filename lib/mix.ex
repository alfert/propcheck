defmodule PropCheck.Mix do
  @moduledoc false

  def default_counter_examples_file do
    Mix.Project.build_path()
    |> Path.dirname()
    |> Path.join("propcheck.ctex")
  end

  def counter_example_file do
    get_in(Mix.Project.config(), [:propcheck, :counter_examples])
  end
end

defmodule Mix.Tasks.Propcheck do
  use Mix.Task

  @shortdoc "Print PropCheck help information"

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

  alias Mix.Tasks.Help

  def run(_) do
    Mix.shell().info("Available PropCheck tasks:\n")
    Help.run(["--search", "propcheck."])
  end

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
            Mix.Shell.IO.info("##{counter}: Property #{prop}: #{inspect(counter_example)}")
            counter + 1
          end
          |> :dets.foldl(1, ctx)

        _ ->
          Mix.Shell.IO.error("Could not open counter examples file #{filename}")
      end
    end
  end
end
