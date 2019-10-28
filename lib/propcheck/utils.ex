defmodule PropCheck.Utils do
  @moduledoc false

  # Merge local options for `PropCheck.quickcheck/2` and
  # `PropCheck.check/2` with global options. Global options
  # take precedence.
  def merge_global_opts(local_opts) do
    local_opts
    |> merge_global_verbose()
    |> merge_global_detect_exceptions()
  end

  defp merge_global_verbose(local_opts) do
    case Application.get_env(:propcheck, :global_verbose) do
      true ->
        [:verbose | local_opts]

      false ->
        [:quiet | local_opts]

      nil ->
        local_opts
    end
  end

  defp merge_global_detect_exceptions(local_opts) do
    case Application.get_env(:propcheck, :global_detect_exceptions) do
      nil ->
        local_opts

      opt ->
        [{:detect_exceptions, opt} | local_opts]
    end
  end

  # Merge options
  def merge(opts1, opts2) do
    opts1
    |> Enum.concat(opts2)
    |> Enum.uniq()
  end

  # Store options in the process dictionary for later retrieval.
  def put_opts(opts) do
    Process.put(:property_opts, opts)
    opts
  end

  # Retrieve stored options from the process dictionary.
  def get_opts do
    Process.get(:property_opts, []) || []
  end

  # Check if verbose should be enabled
  def verbose?(opts) do
    opts
    |> Enum.drop_while(&(&1 not in [:verbose, :quiet]))
    |> case do
      [:verbose | _] -> true
      [:quiet | _] -> false
      _ -> false
    end
  end

  # Check if exception detection should be enabled
  def detect_exceptions?(opts) do
    opts
    |> Enum.drop_while(fn
      {:detect_exceptions, _} -> false
      _ -> true
    end)
    |> case do
      [{:detect_exceptions, detect_exceptions} | _] -> detect_exceptions
      [] -> false
    end
  end

  # Find the output agent in `opts`.
  def output_agent(opts) do
    opts
    |> Enum.find(fn
      {:output_agent, _output_agent} -> true
      _ -> false
    end)
    |> case do
      nil -> nil
      {:output_agent, output_agent} -> output_agent
    end
  end

  # Filter options which are PropCheck specific and not handled by PropEr.
  def to_proper_opts(opts) do
    Enum.reject(opts, fn
      {:output_agent, _} -> true
      {:detect_exceptions, _} -> true
      _ -> false
    end)
  end
end
