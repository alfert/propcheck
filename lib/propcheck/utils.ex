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
    |> PropCheck.Utils.elixirfy_verbose_option()
  end

  def elixirfy_verbose_option(opts) do
    Enum.map(opts, fn
      :verbose -> [{:on_output, &PropCheck.Utils.elixirfy_output/2}, :verbose]
      opt -> opt
    end)
    |> List.flatten()
  end

  def elixirfy_output(~c"Stacktrace: ~p.~n", [stacktrace]) do
    IO.puts("Stacktrace:")
    IO.puts(Exception.format_stacktrace(stacktrace))
    :ok
  end

  def elixirfy_output(~c"An exception was raised:" ++ _, [kind, exception]) do
    IO.puts("An exception was raised:")
    IO.puts(Exception.format(kind, exception))
    :ok
  end

  def elixirfy_output(~c"A linked process died" ++ _, [{reason, stack}]) do
    IO.puts("A linked process died with reason: an exception was raised:")
    IO.puts(Exception.format(:error, reason, stack))
    :ok
  end

  def elixirfy_output(fmt, data), do: do_elixirfy_output(fmt, data)

  defp do_elixirfy_output(fmt, data) do
    {fmt, data} =
      fmt
      |> :io_lib.scan_format(data)
      |> Enum.map(&parse_io_spec_format/1)
      |> :io_lib.unscan_format()

    :io.format(fmt, data)
    :ok
  end

  defp parse_io_spec_format(spec = %{control_char: ?s}) do
    %{spec | args: [inspect(spec.args |> hd, limit: :infinity)]}
  end

  defp parse_io_spec_format(spec = %{control_char: c}) when c in [?w, ?p] do
    args = [inspect(spec.args |> hd, pretty: true, limit: :infinity)]
    %{spec | args: args, control_char: ?s}
  end

  defp parse_io_spec_format(char_or_spec), do: char_or_spec

  @spec toplevels(Graph.t()) :: {:ok, [atom()]} | {:error, String.t()}
  def toplevels(graph) do
    with(
      top_order_verts when is_list(top_order_verts) <- Graph.topsort(graph),
      {:ok, levels} <- toplevels(graph, top_order_verts, [])
    ) do
      {:ok, Enum.reverse(levels)}
    else
      false -> {:error, "A cycle was found"}
    end
  end

  defp toplevels(_, [], levels) do
    {:ok, levels}
  end

  defp toplevels(graph, top_order_verts, levels) do
    {level, rest} =
      Enum.split_while(
        top_order_verts,
        &(Graph.in_degree(graph, &1) == 0)
      )

    reducted_graph = Graph.delete_vertices(graph, level)
    toplevels(reducted_graph, rest, [level | levels])
  end

  def find_all_vars(block) do
    block
    |> Macro.postwalk([], &var_finder/2)
    |> elem(1)
    |> Enum.uniq()
  end

  defp var_finder(block, acc) do
    case block do
      {:^, _, [{var, _, _} | _args]} ->
        pinned = {:^, var}

        case acc do
          [^var | rest] -> {block, [pinned | rest]}
          _ -> {block, [pinned | acc]}
        end

      {var, _, args} when not is_list(args) ->
        {block, [var | acc]}

      _ ->
        {block, acc}
    end
  end

  def unpin_vars(block) do
    var_replacer = fn b ->
      case b do
        {:^, _, [var]} -> var
        _ -> b
      end
    end

    Macro.prewalk(block, var_replacer)
  end
end
