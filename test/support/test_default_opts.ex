defmodule PropCheck.Test.DefaultOpts do
  @moduledoc false

  def config do
    send(self(), :default_opts_is_ran)
    [numtests: 1]
  end
end
