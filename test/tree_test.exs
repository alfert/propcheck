defmodule PropCheck.TreeTest do
	use ExUnit.Case
	alias PropCheck.Test.Tree

	# property "a new stack is empty" do
	# 	forall x in StackMod.stack, do: !StackMod.empty(x)
	# end

	test "all Tree properties" do
        {_, failures} = PropCheck.run(Tree)
        assert length(failures) == 0
    end	
end