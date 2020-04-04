defmodule PropCheck.Instrument do
  @moduledoc """
  Provides functions and macros for instrument byte code with additional yields and
  other constructs to ease testing of concurrent programs and state machines.
  """

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
    {^mod, filename, beam_code} = :code.get_object_code(mod)
    case :beam_lib.chunks(beam_code, [:abstract_code]) do
      {:ok, {^mod, [forms]}} -> {:ok, forms}
      error -> error
    end
  end

  @doc "Instruments the form of a module"
  def instrument_form({:abstract_code, {:raw_abstract_v1, clauses}}) when is_list(clauses) do
    instr_clauses = Enum.map(clauses, &instrument_mod_clause/1)
    {:abstract_form,
      {:raw_abstract_v1,
        instr_clauses}}
  end

  @doc "Instruments the clauses of a module"
  def instrument_mod_clause({:function, line, name, arg_count, body}) do
    instr_body = Enum.map(body, &instrument_body/1)
    {:function, line, name, arg_count, body}
  end
  def instrument_mod_clause(clause), do: clause

  @doc "Instruments the each body (a `:clause`) of a function"
  def instrument_body({:clause, line, args, local_vars, exprs}) do
    instr_exprs = Enum.map(exprs, &instrument_expr/1)
    {:clause, line, args, local_vars, instr_exprs}
  end

  @doc "This is a big switch over all kinds of expressions for instrumenting them"
  def instrument_expr({:atom, _, _} = a), do: a
  def instrument_expr({:bc, line, expr, qs}) do
    {:bc, line, instrument_expr(expr), Enum.map(qs, &instrument_qualifier/1)}
  end
  def instrument_expr({:bin, line, bin_elements}) do
    {:bin, line, Enum.map(bin_elements, &instrument_bin_element/1)}
  end
  def instrument_expr({:block, line, exprs}) do
    {:block, line, Enum.map(exprs, &instrument_expr/1)}
  end
  def instrument_expr({:case, line, expr, clauses}) do
    instr_expr = instrument_expr(expr)
    {:case, line, instr_expr, Enum.map(clauses, &instrument_clause/1)}
  end
  def instrument_expr({:catch, line, expr}), do: {:catch, line, instrument_expr(expr)}
  def instrument_expr({:cons, line, e1, e2}), do: {:cons, line, instrument_expr(e1), instrument_expr(e2)}
  def instrument_expr({:fun, line, cs}) when is_list(cs) do
    {:fun, line, Enum.map(cs, &instrument_clause/1)}
  end
  def instrument_expr({:fun, _, _} = f), do: f
  def instrument_expr({:call, _l, _f, _args} = c), do: instrument_function_call(c)
  def instrument_expr({:remote, _l, _m, _f, _args} = c), do: instrument_function_call(c)
  def instrument_expr({:if, line, cs}), do: {:if, line, Enum.map(cs, &instrument_clause/1)}
  def instrument_expr({:lc, line, e, qs}) do
    {:lc, line, instrument_expr(e), Enum.map(qs, &instrument_qualifier/1)}
  end
  def instrument_expr({:map, line, assocs}), do: {:map, line, Enum.map(assocs, &instrument_assoc/1)}
  def instrument_expr({:map, line, expr, assocs}) do
    {:map, line, instrument_expr(expr), Enum.map(assocs, &instrument_assoc/1)}
  end
  def instrument_expr({:match, line, p, e}) do
    {:match, line, instrument_pattern(p), instrument_expr(e)}
  end
  def instrument_expr({:nil, line}), do: {:nil, line}
  def instrument_expr({:op, line, op, e1}), do: {:op, line, op, instrument_expr(e1)}
  def instrument_expr({:op, line, op, e1, e2}), do: {:op, line, op, instrument_expr(e1), instrument_expr(e2)}
  def instrument_expr({:receive, line, cs} = r), do: instrument_receive(r)
  def instrument_expr({:receive, line, cs, e, b} = r), do: instrument_receive(r)
  def instrument_expr({:record, line, name, fields}) do # record creation
    {:record, line, name, Enum.map(fields, &instrument_expr/1)}
  end
  def instrument_expr({:record, line, e, name, fields}) do # record update
    {:record, line, instrument_expr(e), name, Enum.map(fields, &instrument_expr/1)}
  end
  def instrument_expr({:record_field, line, field, expr}), do: {:record, line, field, instrument_expr(expr)}
  def instrument_expr({:record_field, line, expr, name, field}), do: {:record, line, instrument_expr(expr), name, field}
  def instrument_expr({:record_index, line, _name, _fields} = r), do: r
  def instrument_expr({:tuple, line, es}), do: {:tuple, line, Enum.map(es, &instrument_expr/1)}
  def instrument_expr({:try, line, body, cases, catches, expr}) do
    i_body = Enum.map(body, &instrument_expr/1)
    i_cases = Enum.map(cases, &instrument_clause/1)
    i_catches = Enum.map(catches, &instrument_clause/1)
    {:try, line, i_body, i_cases, i_catches, instrument_expr(expr)}
  end
  def instrument_expr({:var, _l, _name} = v), do: v
  def instrument_expr({literal, _line, _val} = l) when literal in [:atom, :integer, :float, :char, :string], do: l


  def instrument_bin_element({:bin_element, line, expr, size, tsl}) do
    {:bin_element, line, instrument_expr(expr), size, tsl}
  end

  @doc "Instrument case, catch, function clauses"
  def instrument_clause({:clause, line, p, body}) do
    {:clause, line, instrument_pattern(p), Enum.map(body, &instrument_expr/1)}
  end
  def instrument_clause({:clause, line, p, guards, body}) do
    {:clause, line, instrument_pattern(p), Enum.map(guards, &instrument_expr/1), Enum.map(body, &instrument_expr/1)}
  end

  @doc "Instrument qualifiers of list and bit comprehensions"
  def instrument_qualifier({:generate, line, p, e}), do: {:generate, line, instrument_pattern(p), instrument_expr(e)}
  def instrument_qualifier({:b_generate, line, p, e}), do: {:b_generate, line, instrument_pattern(p), instrument_expr(e)}
  def instrument_qualifier(e), do: instrument_expr(e)

  @doc "Instrument patterns, which are mostly expressions, except for variables/atoms"
  def instrument_pattern({x, p, s}), do: {x, instrument_expr(p), s}
  def instrument_pattern(ps) when is_list(ps), do: Enum.map(ps, &instrument_pattern/1)
  def instrument_pattern(p), do: instrument_expr(p)

  def instrument_assoc({assoc, line, key, value}) do
    {assoc, line, instrument_expr(key), instrument_expr(value)}
  end


  def instrument_function_call(c), do: throw "Not Implemented"

  @doc "The receive might be handled differently, therefore it has its own function"
  def instrument_receive({:receive, line, cs} = r) do
    {:receive, line, Enum.map(cs, &instrument_clause/1)}
  end
  def instrument_receive({:receive, line, cs, e, b} = r) do
    {:receive, line, Enum.map(cs, &instrument_clause/1), instrument_expr(e), Enum.map(b, &instrument_expr/1)}
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
