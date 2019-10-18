defmodule PropCheck.App do
  use Application

  alias PropCheck.Mix
  @moduledoc false

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    populate_application_env()

    children = [
      # Define workers and child supervisors to be supervised
      # worker(PropCheck.Worker, [arg1, arg2, arg3])
      worker(PropCheck.CounterStrike,
        [Mix.counter_example_file(), [name: PropCheck.CounterStrike]])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Propcheck.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp populate_application_env do
    Application.put_env(:propcheck, :global_verbose,  global_verbose())
  end

  defp global_verbose do
      "PROPCHECK_VERBOSE"
      |> System.get_env()
      |> case do
        "1" -> true
        "0" -> false
        _ -> nil
      end
  end
end
