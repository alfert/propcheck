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

		# IO.inspect e
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
		pre = TypeExpr.preorder e # |> IO.inspect

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

	test "native lists" do
		typedef = PropCheck.Test.Types.__type_debug__(:my_list, 1) 
			|> PropCheck.Type.parse_type
		assert %PropCheck.Type{} = typedef

		%PropCheck.Type{expr: e, params: [:t]} = typedef

		# IO.inspect e
		constructors = e 
			|> TypeExpr.preorder 
			|> Enum.map fn %TypeExpr{constructor: c} -> c end
		assert [:list, :var] == constructors
	end

	test "explicit lists" do
		typedef = PropCheck.Test.Types.__type_debug__(:safe_stack, 1) 
			|> PropCheck.Type.parse_type
		assert %PropCheck.Type{} = typedef

		%PropCheck.Type{expr: e, params: [:t]} = typedef

		# IO.inspect e
		constructors = e 
			|> TypeExpr.preorder 
			|> Enum.map fn %TypeExpr{constructor: c} -> c end
		assert [:tuple, :ref, :list, :var] == constructors
	end

	test "maps" do
		typedef = PropCheck.Test.Types.__type_debug__(:my_map, 0) 
			|> PropCheck.Type.parse_type
		assert %PropCheck.Type{} = typedef

		%PropCheck.Type{expr: e, params: []} = typedef
		# IO.inspect e

		constructors = e 
			|> TypeExpr.preorder 
			|> Enum.map fn %TypeExpr{constructor: c} -> c end
		assert [:map, :tuple, :ref, :ref, :tuple, :ref, :ref] == constructors
	end

	test "structs" do
		typedef = PropCheck.Test.Types.__type_debug__(:my_struct, 0) 
			|> PropCheck.Type.parse_type
		assert %PropCheck.Type{} = typedef

		%PropCheck.Type{expr: e, params: []} = typedef
		#IO.inspect e

		constructors = e 
			|> TypeExpr.preorder 
			|> Enum.map fn %TypeExpr{constructor: c} -> c end
		assert [:map, :tuple, :literal, :ref, :tuple, :literal, :list, :ref] == constructors
	end

	test "unions" do
		typedef = PropCheck.Test.Types.__type_debug__(:yesno, 0) 
			|> PropCheck.Type.parse_type
		assert %PropCheck.Type{} = typedef

		%PropCheck.Type{expr: e, params: []} = typedef
		#IO.inspect e

		constructors = e 
			|> TypeExpr.preorder 
			|> Enum.map fn %TypeExpr{constructor: c} -> c end
		assert [:union, :literal, :literal] == constructors
	end

	test "ranges" do
		typedef = PropCheck.Test.Types.__type_debug__(:my_small_numbers, 0) 
			|> PropCheck.Type.parse_type
		assert %PropCheck.Type{} = typedef

		%PropCheck.Type{expr: e, params: []} = typedef
		IO.inspect e

		constructors = e 
			|> TypeExpr.preorder 
			|> Enum.map fn %TypeExpr{constructor: c} -> c end
		assert [:range, :literal, :literal] == constructors

	end
end