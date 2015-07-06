defmodule PropCheck.StackTypeTest do
	use ExUnit.Case
	alias PropCheck.Test.Stack


	test "all Stack properties" do
        {_, failures} = (PropCheck.run(Stack) |> IO.inspect)
        assert length(failures) == 0
    end	

	test "all Stack specs" do
        {_, failures} = PropCheck.check_specs(Stack, skip_mfas: [{Stack, :__info__, 1}])
        assert length(failures) == 0
    end	

end