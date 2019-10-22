defmodule PropCheck.OutputAgent do
  @moduledoc """
  An agent to gather unique PropCheck-internal output from tests.
  """
  use Agent

  @doc """
  Start the agent.
  """
  def start_link do
    Agent.start_link(&MapSet.new/0)
  end

  @doc """
  Put new output to the agent.
  """
  def put(agent, string) do
    Agent.update(agent, fn set ->
      MapSet.put(set, string)
    end)
  end

  @doc """
  Stop the agent and retrieve the output.
  """
  def close(agent) do
    output =
      agent
      |> Agent.get(& &1)
      |> MapSet.to_list()
      |> Enum.join("\n")

    :ok = Agent.stop(agent)
    {:ok, output}
  end
end
