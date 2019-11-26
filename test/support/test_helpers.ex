defmodule PropCheck.TestHelpers do
  @moduledoc false

  @doc "Reads properties options from system environment."
  def config do
    [:quiet]
    |> push("PROPCHECK_NUMTESTS", "100", :numtests, &opt_num_value/2)
    |> push("PROPCHECK_SEARCH_STEPS", "1000", :search_steps, &opt_num_value/2)
    |> maybe_push("PROPCHECK_MAX_SIZE", :max_size, &opt_num_value/2)
  end

  @doc "Prints text without new line, but only when ``PROPCHECK_DEBUG` system variable is set."
  def debug(str) do
    if debug?(), do: IO.write(str), else: :ok
  end

  @doc "Prints text with new line, but only when ``PROPCHECK_DEBUG` system variable is set."
  def debugln(str) do
    if debug?(), do: IO.puts(str), else: :ok
  end

  defp debug? do
    case System.get_env("PROPCHECK_DEBUG") do
      "1" -> true
      "true" -> true
      "TRUE" -> true
      _ -> false
    end
  end

  defp opt_num_value(name, val), do: {name, String.to_integer(val)}

  defp opt_bool_value(name, val) do
    case val do
      "1" -> name
      "TRUE" -> name
      "true" -> name
      _ -> nil
    end
  end

  defp push(cfg, env_var, default , opt_name, transform) do
    case System.get_env(env_var) do
      nil -> [transform.(opt_name, default) | cfg]
      val -> [transform.(opt_name, val) | cfg]
    end
  end

  defp maybe_push(cfg, env_var, opt_name, transform) do
    with val when val != nil <- System.get_env(env_var),
         tval when tval != nil <- transform.(opt_name, val)
      do
      [tval | cfg]
      else
        _ -> cfg
    end
  end
end
