defmodule PropCheck.App do
  use Application

  alias PropCheck.Mix
  @moduledoc false

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

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
end
