defmodule PropCheck.Logger do
  require Logger

  @moduledoc false

  @levels ~w(debug info warning error)a

  for level <- @levels, fun = :"log_#{level}" do
    def unquote(fun)(arg) do
      _ = Logger.unquote(level)(arg)
      :ok
    end
  end
end
