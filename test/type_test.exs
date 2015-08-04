defmodule PropCheck.Test.TypeTest do
	use ExUnit.Case

	test "all types available" do
		types = PropCheck.Test.Types
			|> PropCheck.TypeGen.defined_types
			|> List.flatten
		assert types != []
	end

	test "create the typedef" do
		typedef = PropCheck.Test.Types.__type_debug__(:tree, 1) 
			|> PropCheck.Type.parse_type
		assert %PropCheck.Type{} = typedef

		%PropCheck.Type{name: n, kind: k, params: ps, expr: e} = typedef
		assert :tree == n
		assert :opaque == k
		assert [:t] == ps

		IO.inspect e
	end
	
end