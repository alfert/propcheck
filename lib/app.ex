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
    Application.put_env(:propcheck, :global_detect_exceptions,  global_detect_exceptions())
  end

  defp global_verbose do
      "PROPCHECK_VERBOSE"
      |> System.get_env()
      |> env_to_terniary()
  end

  defp global_detect_exceptions do
      "PROPCHECK_DETECT_EXCEPTIONS"
      |> System.get_env()
      |> env_to_terniary()
  end

  defp env_to_terniary("1"), do: true
  defp env_to_terniary("0"), do: false
  defp env_to_terniary(""), do: false
  defp env_to_terniary(nil), do: nil
end
