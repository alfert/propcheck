defmodule VerifyVerbose do
  @moduledoc "Check that setting verboseness using PROPCHECK_VERBOSE works as intended."
  use ExUnit.Case
  use PropCheck

  @moduletag :manual

  property "some property", [:quiet] do
    forall x <- nat() do
      x >= 0
    end
  end

  property "some other property", [:verbose] do
    forall x <- nat() do
      x >= 0
    end
  end
end
