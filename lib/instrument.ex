defmodule PropCheck.Instrument do
  @moduledoc """
  Provides functions and macros for instrument byte code with additional yields and
  other constructs to ease testing of concurrent programs and state machines.
  """

  @doc """
  Handle the instrumentation of a (remote) function call. Must return a
  valid expression in Erlang Abstract Form.
  """
  @callback handle_function_call(call :: any) :: any


  @doc """
  Takes the object code of the module, instruments it and update the module
  in the code server with instrumented byte code.
  """
  def instrument_module(mod) when is_atom(mod) do

    # TODO: hwo to convert a beam ast to an Elixir ast?
    # with :beam_lib we can extract the Erlang AST from the obj_code binary
    # but how to proceed then?
    # ast = instrument_functions(mod, obj_code)
    # {^mod, new_obj_code} = Code.compile_quoted(ast, file)
    # {:module, _new_mod} = :code.load_binary(mod, filename, new_obj_code)
    :not_implemented
  end

  @doc """
  Retrieves the abstract code, i.e. the list of forms, of the given
  module as found in the code server.
  """
  def get_forms_of_module(mod) when is_atom(mod) do
    {^mod, _filename, beam_code} = :code.get_object_code(mod)
    case :beam_lib.chunks(beam_code, [:abstract_code]) do
      {:ok, {^mod, [forms]}} -> {:ok, forms}
      error -> error
    end
  end

  def map(enum, mod, fun) when is_function(fun, 2) do
    Enum.map(enum, &(fun.(mod, &1)))
  end
  def map_expr(enum, mod), do: map(enum, mod, &instrument_expr/2)

  @doc "Instruments the form of a module"
  def instrument_form(mod, {:abstract_code, {:raw_abstract_v1, clauses}}) when is_list(clauses) do
    instr_clauses = map(clauses, mod, &instrument_mod_clause/2)
    {:abstract_form,
      {:raw_abstract_v1,
        instr_clauses}}
  end

  @doc "Instruments the clauses of a module"
  def instrument_mod_clause(mod, {:function, line, name, arg_count, body}) do
    instr_body = map(body, mod, &instrument_body/2)
    {:function, line, name, arg_count, instr_body}
  end
  def instrument_mod_clause(_mod, clause), do: clause

  @doc "Instruments the each body (a `:clause`) of a function"
  def instrument_body(mod, {:clause, line, args, local_vars, exprs}) do
    instr_exprs = map_expr(exprs, mod)
    {:clause, line, args, local_vars, instr_exprs}
  end

  @doc "This is a big switch over all kinds of expressions for instrumenting them"
  def instrument_expr(_mod, {:atom, _, _} = a), do: a
  def instrument_expr(mod, {:bc, line, expr, qs}) do
    {:bc, line, instrument_expr(mod, expr), map(qs, mod, &instrument_qualifier/2)}
  end
  def instrument_expr(mod, {:bin, line, bin_elements}) do
    {:bin, line, map(bin_elements, mod, &instrument_bin_element/2)}
  end
  def instrument_expr(mod, {:block, line, exprs}) do
    {:block, line, map(exprs, mod, &instrument_expr/2)}
  end
  def instrument_expr(mod, {:case, line, expr, clauses}) do
    instr_expr = instrument_expr(mod, expr)
    {:case, line, instr_expr, map(clauses, mod, &instrument_clause/2)}
  end
  def instrument_expr(mod, {:catch, line, expr}), do: {:catch, line, instrument_expr(mod, expr)}
  def instrument_expr(mod, {:cons, line, e1, e2}), do: {:cons, line, instrument_expr(mod, e1), instrument_expr(mod, e2)}
  def instrument_expr(mod, {:fun, line, cs}) when is_list(cs) do
    {:fun, line, map(cs, mod, &instrument_clause/2)}
  end
  def instrument_expr(_mod, {:fun, _, _} = f), do: f
  def instrument_expr(mod, {:call, _l, _f, _args} = c), do: instrument_function_call(mod, c)
  def instrument_expr(mod, {:call, _l, {:remote, _m, _f}, _args} = c), do: instrument_function_call(mod, c)
  def instrument_expr(mod, {:if, line, cs}), do: {:if, line, map(cs, mod, &instrument_clause/2)}
  def instrument_expr(mod, {:lc, line, e, qs}) do
    {:lc, line, instrument_expr(mod, e), map(qs, mod, &instrument_qualifier/2)}
  end
  def instrument_expr(mod, {:map, line, assocs}), do: {:map, line, map(assocs, mod,  &instrument_assoc/2)}
  def instrument_expr(mod, {:map, line, expr, assocs}) do
    {:map, line, instrument_expr(mod, expr), map(assocs, mod, &instrument_assoc/2)}
  end
  def instrument_expr(mod, {:match, line, p, e}) do
    {:match, line, instrument_pattern(mod, p), instrument_expr(mod, e)}
  end
  def instrument_expr(_mod, {:nil, line}), do: {:nil, line}
  def instrument_expr(mod, {:op, line, op, e1}), do: {:op, line, op, instrument_expr(mod, e1)}
  def instrument_expr(mod, {:op, line, op, e1, e2}), do:
    {:op, line, op, instrument_expr(mod, e1), instrument_expr(mod, e2)}
  def instrument_expr(mod, {:receive, _line, _cs} = r), do: instrument_receive(mod, r)
  def instrument_expr(mod, {:receive, _line, _cs, _e, _b} = r), do: instrument_receive(mod, r)
  def instrument_expr(mod, {:record, line, name, fields}) do # record creation
    {:record, line, name, map_expr(fields, mod)}
  end
  def instrument_expr(mod, {:record, line, e, name, fields}) do # record update
    {:record, line, instrument_expr(mod, e), name, map_expr(fields, mod)}
  end
  def instrument_expr(mod, {:record_field, line, field, expr}), do: {:record, line, field, instrument_expr(mod, expr)}
  def instrument_expr(mod, {:record_field, line, expr, name, field}), do:
    {:record, line, instrument_expr(mod, expr), name, field}
  def instrument_expr(_mod, {:record_index, _line, _name, _fields} = r), do: r
  def instrument_expr(mod, {:tuple, line, es}), do: {:tuple, line, map_expr(es, mod)}
  def instrument_expr(mod, {:try, line, body, cases, catches, expr}) do
    i_body = map_expr(body, mod)
    i_cases = map(cases, mod, &instrument_clause/2)
    i_catches = map(catches, mod, &instrument_clause/2)
    {:try, line, i_body, i_cases, i_catches, instrument_expr(mod, expr)}
  end
  def instrument_expr(_mod, {:var, _l, _name} = v), do: v
  def instrument_expr(_mod, {literal, _line, _val} = l) when literal in [:atom, :integer, :float, :char, :string], do: l

  @doc "Instrument a part of binary pattern definition"
  def instrument_bin_element(mod, {:bin_element, line, expr, size, tsl}) do
    {:bin_element, line, instrument_expr(mod, expr), size, tsl}
  end

  @doc "Instrument case, catch, function clauses"
  def instrument_clause(mod, {:clause, line, p, body}) do
    {:clause, line, instrument_pattern(mod, p), map_expr(body, mod)}
  end
  def instrument_clause(mod, {:clause, line, ps, [guards], body}) when is_list(ps) do
    {:clause, line, map_expr(ps, mod), [map_expr(guards, mod)], map_expr(body, mod)}
  end
  def instrument_clause(mod, {:clause, line, ps, guards, body}) when is_list(ps) do
    {:clause, line, map_expr(ps, mod), map_expr(guards, mod), map_expr(body, mod)}
  end

  @doc "Instrument qualifiers of list and bit comprehensions"
  def instrument_qualifier(mod, {:generate, line, p, e}), do: {:generate, line, instrument_pattern(mod, p), instrument_expr(mod, e)}
  def instrument_qualifier(mod, {:b_generate, line, p, e}), do: {:b_generate, line, instrument_pattern(mod, p), instrument_expr(mod, e)}
  def instrument_qualifier(mod, e), do: instrument_expr(mod, e)

  @doc "Instrument patterns, which are mostly expressions, except for variables/atoms"
  # def instrument_pattern(mod, {x, p, s}), do: {x, instrument_expr(mod, p), s}
  def instrument_pattern(mod, ps) when is_list(ps), do: map(ps, mod, &instrument_pattern/2)
  def instrument_pattern(mod, p), do: instrument_expr(mod, p)

  def instrument_assoc(mod, {assoc, line, key, value}) do
    {assoc, line, instrument_expr(mod, key), instrument_expr(mod, value)}
  end

  def instrument_function_call(mod, c), do: mod.handle_function_call(c)

  @doc "The receive might be handled differently, therefore it has its own function"
  def instrument_receive(mod, {:receive, line, cs}) do
    {:receive, line, map(cs, mod, &instrument_clause/2)}
  end
  def instrument_receive(mod, {:receive, line, cs, e, b})  do
    {:receive, line, map(cs, mod, &instrument_clause/2),
      instrument_expr(mod, e), map_expr(b, mod)}
  end


  @doc """
  Instruments the body of a function to handle the `receive do ... end` expression
  for Tracer
  """
  def instrument_elixir_expr(expr, context, instrumenter \\ __MODULE__) do
    IO.puts "instrument function #{context.name}"
    instr_expr = Macro.postwalk(expr, fn
      {:receive, _info, [patterns]} ->
        # identify do: patterns Und after: clause, diese müssen bei
        # gen_receive als Argument übernommen werden.
        IO.puts "instrument receive with pattern #{Macro.to_string patterns}"
        IO.puts "instrument receive with pattern #{inspect patterns}"
        IO.puts "Body expression is: #{Macro.to_string expr}"
        gen_receive(patterns)
      {:receive, _info, [patterns, _after_pattern]} ->
        IO.puts "instrument a receive with an after pattern - this is ignored!"
        gen_receive(patterns)
      any -> any
    end)
    IO.puts "New body is: #{Macro.to_string(instr_expr)}"
    IO.puts "New body is: #{inspect instr_expr, pretty: true}"
    instr_expr
  end

  def gen_receive(patterns) do
    throw "Not Implemented"
  end
end
