defmodule PropCheck.Test.TypeTest do
	use ExUnit.Case
	alias PropCheck.Type.TypeExpr
	alias PropCheck.Type

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

	test "simple types" do
		typedef = PropCheck.Test.Types.__type_debug__(:my_numbers, 0) 
			|> PropCheck.Type.parse_type
		assert %PropCheck.Type{} = typedef

		%PropCheck.Type{expr: e, params: []} = typedef
		
		# IO.inspect typedef

		constructors = e 
			|> TypeExpr.preorder 
			|> Enum.map fn %TypeExpr{constructor: c} -> c end
		assert [:ref] == constructors
		assert %TypeExpr{constructor: :ref, args: [:integer]} = e
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

	test "nonempty lists" do
		typedef = PropCheck.Test.Types.__type_debug__(:my_non_empty_list, 1) 
			|> PropCheck.Type.parse_type
		assert %PropCheck.Type{} = typedef

		%PropCheck.Type{expr: e, params: [:t]} = typedef

		IO.inspect e
		constructors = e 
			|> TypeExpr.preorder 
			|> Enum.map fn %TypeExpr{constructor: c} -> c end
		assert [:list, :var, :literal] == constructors
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
		# IO.inspect e

		constructors = e 
			|> TypeExpr.preorder 
			|> Enum.map fn %TypeExpr{constructor: c} -> c end
		assert [:range, :literal, :literal] == constructors
	end

	test "any function" do
		typedef = PropCheck.Test.Types.__type_debug__(:any_fun, 0) 
			|> PropCheck.Type.parse_type
		assert %PropCheck.Type{} = typedef

		%PropCheck.Type{expr: e, params: []} = typedef
		# IO.inspect e

		constructors = e 
			|> TypeExpr.preorder 
			|> Enum.map fn %TypeExpr{constructor: c} -> c end
		assert [:fun, :list, :literal, :ref] == constructors
	end

	test "environment construction" do
		mod = PropCheck.Test.Types
		types = PropCheck.Test.Types.__type_debug__()
		assert length(types) > 0

		env = PropCheck.Type.create_environment(types, mod)

		assert env |> Dict.has_key? {mod, :any_fun, 0}
		assert env |> Dict.has_key? {mod, :my_non_empty_list, 1}
		assert env |> Dict.has_key? {mod, :safe_stack, 1}
	end

	test "check non-recursive types" do
		mod = PropCheck.Test.Types
		types = PropCheck.Test.Types.__type_debug__()
		assert length(types) > 0
		env = Type.create_environment(types, mod)

	 	refute Type.is_recursive({mod, :my_numbers, 0}, env)
	 	refute Type.is_recursive({mod, :yesno, 0}, env)
	 	refute Type.is_recursive({mod, :my_list, 1}, env)
	 	refute Type.is_recursive({mod, :safe_stack, 1}, env)
	end

	test "check recursive types" do
		mod = PropCheck.Test.Types
		types = PropCheck.Test.Types.__type_debug__()
		assert length(types) > 0
		env = Type.create_environment(types, mod)

	 	assert Type.is_recursive({mod, :tree, 1}, env)
	 	# wir brauchen was anderes, das in den parameter rekursive ist
	end
end