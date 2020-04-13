defmodule PropCheck.Instrument do
  @moduledoc """
  Provides functions and macros for instrument byte code with additional yields and
  other constructs to ease testing of concurrent programs and state machines.
  """

  require Logger

  @doc """
  Handle the instrumentation of a (remote) function call. Must return a
  valid expression in Erlang Abstract Form.
  """
  @callback handle_function_call(call :: any) :: any

  @doc """
  A callback to decide if the function `mod:fun` with any arity is a candidate
  for instrumentation. The default implementation is simply calling
  `instrumentable_function/2`.
  """
  @callback is_instrumentable_function(mod ::module, fun :: atom) :: boolean

  def instrument_app(app, instrumenter) do
    case  Application.spec(app, :modules) do
      mods when is_list(mods) -> Enum.each(mods, &(instrument_module(&1, instrumenter)))
      nil -> :ok
    end
  end

  @doc """
  Takes the object code of the module, instruments it and update the module
  in the code server with instrumented byte code.
  """
  @spec instrument_module(mod :: module, instrumeter :: module) :: any
  def instrument_module(mod, instrumenter) when is_atom(mod) and is_atom(instrumenter) do
    # 1. Get the forms of the mod
    {:ok, filename, forms} = get_forms_of_module(mod)
    case is_instrumented?(forms) do
      false ->
        # 2. instruments the forms of the mod
        {:abstract_code, {:raw_abstract_v1, altered_forms}} = instrument_forms(instrumenter, forms)
        # 3. Compile them with :compile.forms
        instr_attribute = {:attribute, 1, :instrumented, PropCheck}
        instrumented_form = add_attribute([instr_attribute], altered_forms)
        compile_module(mod, filename, instrumented_form)
      attribute ->
        Logger.error "Module #{inspect mod} is alread instrumented: #{inspect attribute}"
    end
  end

  def add_attribute(attrs, forms), do: add_attribute(attrs, [], forms)
  def add_attribute([], forms, []), do: Enum.reverse(forms)
  def add_attribute([], fs, [f | tail]), do: add_attribute([], [f | fs], tail)
  def add_attribute(as, fs1, [{:attribute, _, _, _} = a | tail]), do: add_attribute(as, [a | fs1], tail)
  def add_attribute([attr | as], fs1, tail), do: add_attribute(as, [attr | fs1], tail)

  @doc """
  Retrieves the abstract code, i.e. the list of forms, of the given
  module as found in the code server.
  """
  def get_forms_of_module(mod) when is_atom(mod) do
    {^mod, beam_code, filename} = :code.get_object_code(mod)
    case :beam_lib.chunks(beam_code, [:abstract_code]) do
      {:ok, {^mod, [forms]}} -> {:ok, filename, forms}
      error -> error
    end
  end

  @doc """
  Compiles the abstract code of a module and loads it immediately into
  the VM.
  """
  def compile_module(mod, filename, {:abstract_code, {:raw_abstract_v1, clauses}} = _abstract_code) do
    compile_module(mod, filename, clauses)
  end
  def compile_module(mod, filename, clauses) when is_list(clauses) do
    options = [:binary, :debug_info, :return, :verbose]
    case :compile.noenv_forms(clauses, options) do
      {:ok, ^mod, bin_code, warnings} ->
        Logger.debug "Module #{inspect mod} is compiled"
        Logger.debug "Now loading the module"
        {:module, ^mod} = :code.load_binary(mod, filename, bin_code)
        {:ok, mod, bin_code, warnings}
      error -> error
    end
  end

  @doc "Checks if the code is already instrumented. If not, returns `false` otherwise returns the attribute"
  def is_instrumented?({:abstract_code, {:raw_abstract_v1, clauses}}), do: is_instrumented?(clauses)
  def is_instrumented?(clauses) when is_list(clauses) do
    Enum.find(clauses, false, fn
      {:attribute, _line, :instrumented, _} -> true
      _ -> false
    end)
  end
  def is_instrumented?(mod) do
    mod.module_info(:attributes)
    |> Keyword.has_key?(:instrumented)
  end

  # Helper function for passing the module through the mapping process
  defp map(enum, mod, fun) when is_function(fun, 2) do
    Enum.map(enum, &(fun.(mod, &1)))
  end
  # Helper function for mapping expressions
  defp map_expr(enum, mod), do: map(enum, mod, &instrument_expr/2)

  @doc "Instruments the forms of a module"
  def instrument_forms(instrumenter, {:abstract_code, {:raw_abstract_v1, clauses}}) when is_list(clauses) do
    instr_clauses = map(clauses, instrumenter, &instrument_mod_clause/2)
    {:abstract_code,
      {:raw_abstract_v1,
        instr_clauses}}
  end

  @doc "Instruments the clauses of a module"
  def instrument_mod_clause(instrumenter, {:function, line, name, arg_count, body}) do
    instr_body = map(body, instrumenter, &instrument_body/2)
    {:function, line, name, arg_count, instr_body}
  end
  def instrument_mod_clause(_instrumenter, clause), do: clause

  @doc "Instruments the each body (a `:clause`) of a function"
  def instrument_body(instrumenter, {:clause, line, args, local_vars, exprs}) do
    instr_exprs = map_expr(exprs, instrumenter)
    {:clause, line, args, local_vars, instr_exprs}
  end

  @doc "This is a big switch over all kinds of expressions for instrumenting them"
  def instrument_expr(_instrumenter, {:atom, _, _} = a), do: a
  def instrument_expr(instrumenter, {:bc, line, expr, qs}) do
    {:bc, line, instrument_expr(instrumenter, expr), map(qs, instrumenter, &instrument_qualifier/2)}
  end
  def instrument_expr(instrumenter, {:bin, line, bin_elements}) do
    {:bin, line, map(bin_elements, instrumenter, &instrument_bin_element/2)}
  end
  def instrument_expr(instrumenter, {:block, line, exprs}) do
    {:block, line, map_expr(exprs, instrumenter)}
  end
  def instrument_expr(instrumenter, {:case, line, expr, clauses}) do
    instr_expr = instrument_expr(instrumenter, expr)
    {:case, line, instr_expr, map(clauses, instrumenter, &instrument_clause/2)}
  end
  def instrument_expr(instrumenter, {:catch, line, expr}), do: {:catch, line, instrument_expr(instrumenter, expr)}
  def instrument_expr(instrumenter, {:cons, line, e1, e2}), do: {:cons, line, instrument_expr(instrumenter, e1), instrument_expr(instrumenter, e2)}
  def instrument_expr(instrumenter, {:fun, line, cs}) when is_list(cs) do
    {:fun, line, map(cs, instrumenter, &instrument_clause/2)}
  end
  def instrument_expr(_instrumenter, {:fun, _, _} = f), do: f
  def instrument_expr(instrumenter, {:call, _l, {:remote, _m, _f}, _args} = c), do: instrument_function_call(instrumenter, c)
  def instrument_expr(instrumenter, {:call, _l, _f, _args} = c), do: instrument_function_call(instrumenter, c)
  def instrument_expr(instrumenter, {:if, line, cs}), do: {:if, line, map(cs, instrumenter, &instrument_clause/2)}
  def instrument_expr(instrumenter, {:lc, line, e, qs}) do
    {:lc, line, instrument_expr(instrumenter, e), map(qs, instrumenter, &instrument_qualifier/2)}
  end
  def instrument_expr(instrumenter, {:map, line, assocs}), do: {:map, line, map(assocs, instrumenter,  &instrument_assoc/2)}
  def instrument_expr(instrumenter, {:map, line, expr, assocs}) do
    {:map, line, instrument_expr(instrumenter, expr), map(assocs, instrumenter, &instrument_assoc/2)}
  end
  def instrument_expr(instrumenter, {:match, line, p, e}) do
    {:match, line, instrument_pattern(instrumenter, p), instrument_expr(instrumenter, e)}
  end
  def instrument_expr(_instrumenter, {:nil, line}), do: {:nil, line}
  def instrument_expr(instrumenter, {:op, line, op, e1}), do: {:op, line, op, instrument_expr(instrumenter, e1)}
  def instrument_expr(instrumenter, {:op, line, op, e1, e2}), do:
    {:op, line, op, instrument_expr(instrumenter, e1), instrument_expr(instrumenter, e2)}
  def instrument_expr(instrumenter, {:receive, _line, _cs} = r), do: instrument_receive(instrumenter, r)
  def instrument_expr(instrumenter, {:receive, _line, _cs, _e, _b} = r), do: instrument_receive(instrumenter, r)
  def instrument_expr(instrumenter, {:record, line, name, fields}) do # record creation
    {:record, line, name, map_expr(fields, instrumenter)}
  end
  def instrument_expr(instrumenter, {:record, line, e, name, fields}) do # record update
    {:record, line, instrument_expr(instrumenter, e), name, map_expr(fields, instrumenter)}
  end
  def instrument_expr(instrumenter, {:record_field, line, field, expr}), do: {:record, line, field, instrument_expr(instrumenter, expr)}
  def instrument_expr(instrumenter, {:record_field, line, expr, name, field}), do:
    {:record, line, instrument_expr(instrumenter, expr), name, field}
  def instrument_expr(_instrumenter, {:record_index, _line, _name, _fields} = r), do: r
  def instrument_expr(instrumenter, {:tuple, line, es}), do: {:tuple, line, map_expr(es, instrumenter)}
  def instrument_expr(instrumenter, {:try, line, body, cases, catches, expr}) do
    i_body = map_expr(body, instrumenter)
    i_cases = map(cases, instrumenter, &instrument_clause/2)
    i_catches = map(catches, instrumenter, &instrument_clause/2)
    {:try, line, i_body, i_cases, i_catches, instrument_expr(instrumenter, expr)}
  end
  def instrument_expr(_instrumenter, {:var, _l, _name} = v), do: v
  def instrument_expr(_instrumenter, {literal, _line, _val} = l) when literal in [:atom, :integer, :float, :char, :string], do: l

  @doc "Instrument a part of binary pattern definition"
  def instrument_bin_element(instrumenter, {:bin_element, line, expr, size, tsl}) do
    {:bin_element, line, instrument_expr(instrumenter, expr), size, tsl}
  end

  @doc "Instrument case, catch, function clauses"
  def instrument_clause(instrumenter, {:clause, line, p, body}) do
    {:clause, line, instrument_pattern(instrumenter, p), map_expr(body, instrumenter)}
  end
  # def instrument_clause(instrumenter, {:clause, line, ps, body}) when is_list(ps) do
  #   {:clause, line, map_expr(ps, instrumenter), map_expr(body, instrumenter)}
  # end
  def instrument_clause(instrumenter, {:clause, line, ps, [guards], body}) when is_list(ps) and is_list(guards) do
    {:clause, line, map_expr(ps, instrumenter), [map_expr(guards, instrumenter)], map_expr(body, instrumenter)}
  end
  def instrument_clause(instrumenter, {:clause, line, ps, guards, body}) when is_list(ps) do
    {:clause, line, map_expr(ps, instrumenter), map_expr(guards, instrumenter), map_expr(body, instrumenter)}
  end

  @doc "Instrument qualifiers of list and bit comprehensions"
  def instrument_qualifier(instrumenter, {:generate, line, p, e}), do: {:generate, line, instrument_pattern(instrumenter, p), instrument_expr(instrumenter, e)}
  def instrument_qualifier(instrumenter, {:b_generate, line, p, e}), do: {:b_generate, line, instrument_pattern(instrumenter, p), instrument_expr(instrumenter, e)}
  def instrument_qualifier(instrumenter, e), do: instrument_expr(instrumenter, e)

  @doc "Instrument patterns, which are mostly expressions, except for variables/atoms"
  # def instrument_pattern(instrumenter, {x, p, s}), do: {x, instrument_expr(instrumenter, p), s}
  def instrument_pattern(instrumenter, ps) when is_list(ps), do: map(ps, instrumenter, &instrument_pattern/2)
  def instrument_pattern(instrumenter, p), do: instrument_expr(instrumenter, p)

  def instrument_assoc(instrumenter, {assoc, line, key, value}) do
    {assoc, line, instrument_expr(instrumenter, key), instrument_expr(instrumenter, value)}
  end

  @doc """
  Instruments a function call and gives control the handler module `instrumenter`.
  For now, we only instrumenting a call, if it is any of the interesting functions,
  i.e those might be a source of concurrency problems due to a shared mutable
  state or otherwise tinkering with scheduling.
  """
  def instrument_function_call(instrumenter, {:call, line, {:remote, line2, m, f}, as}) do
    module = instrument_expr(instrumenter, m)
    fun = instrument_expr(instrumenter, f)
    args = map_expr(as, instrumenter)
    case instrumenter.is_instrumentable_function(m, f) do
      true -> instrumenter.handle_function_call({:call, line, {:remote, line2, module, fun}, args})
      _ -> {:call, line, {:remote, line2, module, fun}, args}
    end
  end
  def instrument_function_call(instrumenter, {:call, line, f, as}) do
    fun = instrument_expr(instrumenter, f)
    args = map_expr(as, instrumenter)
    {:call, line, fun, args}
  end

  @doc "The receive might be handled differently, therefore it has its own function"
  def instrument_receive(instrumenter, {:receive, line, cs}) do
    {:receive, line, map(cs, instrumenter, &instrument_clause/2)}
  end
  def instrument_receive(instrumenter, {:receive, line, cs, e, b})  do
    {:receive, line, map(cs, instrumenter, &instrument_clause/2),
      instrument_expr(instrumenter, e), map_expr(b, instrumenter)}
  end

  @doc """
  Prepends the call to `to_be_wrapped_call` by a call to `new_call`.
  The result of `new_call` is ignored.
  """
  def prepend_call(to_be_wrapped_call, new_call) do
    {:block, [generated: true], [new_call, to_be_wrapped_call]}
  end

  @doc """
  Enocdes a call given as tuple `{m, f, a}` as Elixir values into an
  abstract erlang form
  """
  def encode_call({m, f, a}) do
    line = 0 # [generated: true]
    {:call, line,
      {:remote, line,
        {:atom, line, m},
        {:atom, line, f}},
      Enum.map(a, &encode_value/1)}
  end
  def encode_call(m, f, a) when is_atom(m) and is_atom(f) and is_list(a),
    do: encode_call({m, f, a})

  @doc "Encodes a value"
  def encode_value(nil), do: {:nil, [generated: true]}
  def encode_value(value) when is_atom(value), do: {:atom, [generated: true], value}
  def encode_value(value) when is_integer(value), do: {:integer, [generated: true], value}
  def encode_value(value) when is_float(value), do: {:float, [generated: true], value}
  def encode_value(value) when is_binary(value), do:
    {:bin, [generated: true],
      [{:bin_element, [generated: true], {:string, [generated: true], String.to_charlist(value)},
        :default, :default}]}
  def encode_value([]), do: encode_value(nil)
  def encode_value(l) when is_list(l) do
    l
    |> Enum.reverse()
    |> Enum.reduce({nil, 0}, fn v, acc -> {:cons, 0, encode_value(v), acc} end)
  end
  def encode_value(t) when is_tuple(t) do
    {:tuple, [generated: true],
      t
      |> Tuple.to_list()
      |> Enum.map(&encode_value/1)}
  end
  def encode_value(_unknown), do: throw ArgumentError

  @doc "Encodes a call to `:erlang.yield()"
  def call_yield do
    encode_call({:erlang, :yield, []})
  end

  # Generate the matcher for interestng functions by a macro
  # This list is taken from the opensource version of Pulse
  # (https://github.com/prowessproject/pulse-time/blob/master/src/pulse_time_scheduler.erl)
  def instrumentable_function({:atom, _, :ets}, {:atom, _, :lookup}), do: true
  def instrumentable_function({:atom, _, :ets}, {:atom, _, :lookup_element}), do: true
  def instrumentable_function({:atom, _, :ets}, {:atom, _, :update_element}), do: true
  def instrumentable_function({:atom, _, :ets}, {:atom, _, :insert}), do: true
  def instrumentable_function({:atom, _, :ets}, {:atom, _, :insert_new}), do: true
  def instrumentable_function({:atom, _, :ets}, {:atom, _, :delete_object}), do: true
  def instrumentable_function({:atom, _, :ets}, {:atom, _, :delete}), do: true
  def instrumentable_function({:atom, _, :ets}, {:atom, _, :delete_all_objects}), do: true
  def instrumentable_function({:atom, _, :ets}, {:atom, _, :select_delete}), do: true
  def instrumentable_function({:atom, _, :ets}, {:atom, _, :match_delete}), do: true
  def instrumentable_function({:atom, _, :ets}, {:atom, _, :match_object}), do: true
  def instrumentable_function({:atom, _, :ets}, {:atom, _, :member}), do: true
  def instrumentable_function({:atom, _, :ets}, {:atom, _, :new}), do: true

  def instrumentable_function({:atom, _, :gen_server}, {:atom, _, :start_link}), do: true
  def instrumentable_function({:atom, _, :gen_server}, {:atom, _, :start}), do: true
  def instrumentable_function({:atom, _, :gen_server}, {:atom, _, :call}), do: true
  def instrumentable_function({:atom, _, :gen_server}, {:atom, _, :cast}), do: true
  def instrumentable_function({:atom, _, :gen_server}, {:atom, _, :server}), do: true
  def instrumentable_function({:atom, _, :gen_server}, {:atom, _, :loop}), do: true

  def instrumentable_function({:atom, _, :supervisor}, {:atom, _, :start_link}), do: true
  def instrumentable_function({:atom, _, :supervisor}, {:atom, _, :start_child}), do: true
  def instrumentable_function({:atom, _, :supervisor}, {:atom, _, :which_children}), do: true

  def instrumentable_function({:atom, _, :timer}, {:atom, _, :sleep}), do: true
  def instrumentable_function({:atom, _, :timer}, {:atom, _, :apply_after}), do: true
  def instrumentable_function({:atom, _, :timer}, {:atom, _, :exit_after}), do: true

  def instrumentable_function({:atom, _, :erlang}, {:atom, _, :spawn}), do: true
  def instrumentable_function({:atom, _, :erlang}, {:atom, _, :spawn_link}), do: true
  def instrumentable_function({:atom, _, :erlang}, {:atom, _, :link}), do: true
  def instrumentable_function({:atom, _, :erlang}, {:atom, _, :process_flag}), do: true
  # def instrumentable_function({:atom, _, :erlang}, {:atom, _, yield}), do: true
  def instrumentable_function({:atom, _, :erlang}, {:atom, _, :now}), do: true
  def instrumentable_function({:atom, _, :erlang}, {:atom, _, :is_process_alive}), do: true
  def instrumentable_function({:atom, _, :erlang}, {:atom, _, :demonitor}), do: true
  def instrumentable_function({:atom, _, :erlang}, {:atom, _, :monitor}), do: true
  def instrumentable_function({:atom, _, :erlang}, {:atom, _, :exit}), do: true

  def instrumentable_function({:atom, _, :gen_event}, {:atom, _, :start_link}), do: true
  def instrumentable_function({:atom, _, :gen_event}, {:atom, _, :send}), do: true
  def instrumentable_function({:atom, _, :gen_event}, {:atom, _, :add_handler}), do: true
  def instrumentable_function({:atom, _, :gen_event}, {:atom, _, :notify}), do: true

  def instrumentable_function({:atom, _, :gen_fsm}, {:atom, _, :start_link}), do: true
  def instrumentable_function({:atom, _, :gen_fsm}, {:atom, _, :send_event}), do: true
  def instrumentable_function({:atom, _, :gen_fsm}, {:atom, _, :send_all_state_event}), do: true
  def instrumentable_function({:atom, _, :gen_fsm}, {:atom, _, :sync_send_all_state_event}), do: true

  def instrumentable_function({:atom, _, :io}, {:atom, _, :format}), do: true

  def instrumentable_function({:atom, _, :file}, {:atom, _, :write_file}), do: true

  def instrumentable_function({:atom, _, :"Elixir.IO"}, {:atom, _, :puts}), do: true

  def instrumentable_function(_mod, _fun), do: false

  # @doc """
  # Instruments the body of a function to handle the `receive do ... end` expression
  # for Tracer
  # """
  # def instrument_elixir_expr(expr, context, instrumenter \\ __MODULE__) do
  #   IO.puts "instrument function #{context.name}"
  #   instr_expr = Macro.postwalk(expr, fn
  #     {:receive, _info} ->
  #       # identify do: patterns Und after: clause, diese müssen bei
  #       # gen_receive als Argument übernommen werden.
  #       IO.puts "instrument receive with pattern #{Macro.to_string patterns}"
  #       IO.puts "instrument receive with pattern #{inspect patterns}"
  #       IO.puts "Body expression is: #{Macro.to_string expr}"
  #       gen_receive(patterns)
  #     {:receive, _info} ->
  #       IO.puts "instrument a receive with an after pattern - this is ignored!"
  #       gen_receive(patterns)
  #     any -> any
  #   end)
  #   IO.puts "New body is: #{Macro.to_string(instr_expr)}"
  #   IO.puts "New body is: #{inspect instr_expr, pretty: true}"
  #   instr_expr
  # end

  # def gen_receive(patterns) do
  #   throw "Not Implemented"
  # end
end
