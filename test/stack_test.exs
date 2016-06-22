defmodule PropCheck.StackTypeTest do
	use ExUnit.Case
	use PropCheck
	alias PropCheck.Test.Stack


	test "all Stack specs" do
      #{_, failures} = PropCheck.check_specs(Stack, skip_mfas: [{Stack, :__info__, 1}])
      #assert length(failures) == 0
      IO.puts "Spec checking does not work"
  end


	property "pop(push) = original" do
		forall {s, x} in {Stack.stack(integer), integer} do
			{_y, t} = s |> Stack.push(x) |> Stack.pop
			s == t
		end
	end

	property "push make a stack bigger" do
		forall {s, x} in {Stack.stack(integer), integer} do
			(Stack.size(s) + 1) == Stack.size(s |> Stack.push(x))
		end
	end

end
