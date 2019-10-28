defmodule PropCheck.DeriveGenerators.NotSupported do
  @moduledoc """
  Exception indicated that a certain type cannot be turned into a generator.
  """

  defexception [:message, :type, :reason]

  @impl true
  def exception(opts) do
    type = opts[:type]
    reason = opts[:reason]
    %__MODULE__{message: "Type '#{type}' not supported. Reason: #{reason}"}
  end
end

