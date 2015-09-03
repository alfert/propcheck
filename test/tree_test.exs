defmodule PropCheck.TreeTest do
	use ExUnit.Case
	alias PropCheck.Test.Tree
	use PropCheck.Properties

	prop_test Tree

end