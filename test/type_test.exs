defmodule PropCheck.Test.TypeTest do
	use ExUnit.Case
	alias PropCheck.Type.TypeExpr
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
		%TypeExpr{constructor: :union, args: u_args} = e
		# Problem: node(t) must be a :ref and not be a :literal
		cs = u_args |> Enum.map fn %TypeExpr{constructor: c} -> c end
		assert cs |> Enum.any? &(&1 == :literal) # this is the :leaf part
		assert cs |> Enum.any? &(&1 == :tuple) # this is the node part
	end 
	
	test "preorder of the tree" do
		typedef = PropCheck.Test.Types.__type_debug__(:tree, 1) 
			|> PropCheck.Type.parse_type
		assert %PropCheck.Type{} = typedef

		%PropCheck.Type{expr: e} = typedef
		pre = IO.inspect TypeExpr.preorder e

		constructors = (pre |> Enum.map fn %TypeExpr{constructor: c} -> c end)
		assert [:union, :literal, :tuple, :literal, :var, :ref, :ref] == constructors
	end

	test "native tuples" do
		typedef = PropCheck.Test.Types.__type_debug__(:my_int_tuple, 0) 
			|> PropCheck.Type.parse_type
		assert %PropCheck.Type{} = typedef

		%PropCheck.Type{expr: e, params: []} = typedef

		constructors = e 
			|> TypeExpr.preorder 
			|> Enum.map fn %TypeExpr{constructor: c} -> c end
		assert [:tuple, :ref, :ref] == constructors
	end

end