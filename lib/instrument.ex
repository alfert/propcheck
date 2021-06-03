defmodule PropCheck.Instrument do
  @moduledoc """
  Provides functions and macros for instrument byte code with additional yields and
  other constructs to ease testing of concurrent programs and state machines.

  ## Why is instrumentation important?

  The Erlang scheduler is relatively predictable and stable with regard to pre-emptive
  scheduling. This means that every run has more or the less the same amount of
  virtual machine instructions before a switch to another process happens. These
  process switches are required to reveal any concurrency bugs. A simple way to
  provoke more process switches are calls to `:erlang.yield()` which gives the scheduler
  the possibility to switch early on to another process. It is not defined if
  the scheduler reacts on this hint, but it often does and allows for more
  unpredictable schedules revealing more concurrency bugs.

  The usual advice is to sprinkle the code under test with manually added
  calls to `:erlang.yield()`, but this is a daunting task. Additionally, you
  need to remove this additional code before production use.

  ## The instrumentation

  The functions in this module automate the instrumentation immediately before
  running the tests. We instrument call to "interesting" functions of the Erlang
  and Elixir ecosystem, e.g. calls to `GenServer` or `ets` tables. We do this by examining
  the byte code, checking each function call, and if we found some interesting call target,
  we add a call to `:erlang.yield()` immediately before. This is what the
  `PropCheck.YieldInstrumenter` module provides. It implements the behaviour `Instrument`,
  which requires the implementation of two callbacks `c:handle_function_call/1` and
  `c:is_instrumentable_function/2`. After instrumentation, the code reloading mechanism of
  the Erlang VM enables the new code and the tests can run.

  ## Typical usage

  To ensure instrumentation before running the tests, you implement the `setup_all` macro
  of `ExUnit`:

      setup_all do
        Instrument.instrument_module(Cache, YieldInstrumenter)
        :ok # no update of a context
      end

  In this example, we instrument only a specific module. You can also instrument
  all modules of an application by calling `Instrument.instrument_app(:my_app_under_test, YieldInstrumenter)`.

  ## Implementing your own instrumenter

  For implementing your own instrumenter, you need to get acquainted with the Erlang
  Abstract Form (EAF), which is the internal abstract syntax tree available to the Erlang VM at runtime.
  This format is quite different from the Elixir AST, in particular it has not the regular form but
  consists of many different structures. This requires a lot of cases to be handled for analyizing
  the AST. Little helpers for encoding the instrumented code is provided by `encode_call/1` and
  `encode_value/1` as well as by `prepend_call/2`. For debugging and revealing the structure of
  a specific EAF, you can use `print_fun/1`.

  """

  require Logger

  @typedoc "The type for a node in the Erlang Abstract Form encoding an atom value"
  @type erl_ast_atom_type :: {:atom, any, atom}

  @typedoc "The type for a remote call in Erlang Abstract Form"
  @type erl_ast_remote_call ::
          {:call, any, {:remote, any, erl_ast_atom_type, erl_ast_atom_type()}, [any]}

  @typedoc "Type type for a block of expression in Erlang Abstract Form"
  @type erl_ast_block :: {:block, any, [any]}

  @doc """
  Handle the instrumentation of a (remote) function call. Must return a
  valid expression in Erlang Abstract Form.
  """
  @callback handle_function_call(call :: erl_ast_remote_call) :: :erl_parse.abstract_expr()

  @doc """
  A callback to decide if the function `mod:fun` with any arity is a candidate
  for instrumentation. The default implementation is simply calling
  `instrumentable_function/2`.
  """
  @callback is_instrumentable_function(mod :: erl_ast_atom_type, fun :: erl_ast_atom_type) ::
              boolean

  @doc """
  Instruments all modules of an entire OTP application.
  """
  @spec instrument_app(app :: atom, instrumenter :: module) :: :ok
  def instrument_app(app, instrumenter) do
    case Application.spec(app, :modules) do
      mods when is_list(mods) -> Enum.each(mods, &instrument_module(&1, instrumenter))
      nil -> :ok
    end
  end

  @doc """
  Takes the object code of the module, instruments it and update the module
  in the code server with instrumented byte code.
  """
  @spec instrument_module(mod :: module, instrumenter :: module) :: :ok
  def instrument_module(mod, instrumenter) when is_atom(mod) and is_atom(instrumenter) do
    # 1. Get the forms of the mod
    {:ok, filename, forms} = get_forms_of_module(mod)

    case is_instrumented?(forms) do
      false ->
        # 2. instruments the forms of the mod
        {:abstract_code, {:raw_abstract_v1, altered_forms}} =
          instrument_forms(instrumenter, forms)

        # 3. Compile them with :compile.forms
        instr_attribute = {:attribute, 1, :instrumented, PropCheck}
        instrumented_form = add_attribute([instr_attribute], altered_forms)
        compile_module(mod, filename, instrumented_form)

      attribute ->
        Logger.error("Module #{inspect(mod)} is alread instrumented: #{inspect(attribute)}")
    end
  end

  @doc false
  def add_attribute(attrs, forms), do: add_attribute(attrs, [], forms)
  @doc false
  def add_attribute([], forms, []), do: Enum.reverse(forms)
  def add_attribute([], fs, [f | tail]), do: add_attribute([], [f | fs], tail)

  def add_attribute(as, fs1, [{:attribute, _, _, _} = a | tail]),
    do: add_attribute(as, [a | fs1], tail)

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
  def compile_module(mod, filename, _code = {:abstract_code, {:raw_abstract_v1, clauses}}) do
    compile_module(mod, filename, clauses)
  end

  def compile_module(mod, filename, clauses) when is_list(clauses) do
    options = [:binary, :debug_info, :return, :verbose]

    case :compile.noenv_forms(clauses, options) do
      {:ok, ^mod, bin_code, warnings} ->
        _ignore = Logger.debug("Module #{inspect(mod)} is compiled")
        _ignore = Logger.debug("Now loading the module")
        {:module, ^mod} = :code.load_binary(mod, filename, bin_code)
        {:ok, mod, bin_code, warnings}

      error ->
        error
    end
  end

  @doc "Checks if the code is already instrumented. If not, returns `false` otherwise returns `true`"
  def is_instrumented?(_module_form = {:abstract_code, {:raw_abstract_v1, clauses}}),
    do: is_instrumented?(clauses)

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
    Enum.map(enum, &fun.(mod, &1))
  end

  # Helper function for mapping expressions
  defp map_expr(enum, mod), do: map(enum, mod, &instrument_expr/2)

  @doc false
  # "Instruments the forms of a module"
  def instrument_forms(instrumenter, {:abstract_code, {:raw_abstract_v1, clauses}})
      when is_list(clauses) do
    instr_clauses = map(clauses, instrumenter, &instrument_mod_clause/2)
    {:abstract_code, {:raw_abstract_v1, instr_clauses}}
  end

  # "Instruments the clauses of a module"
  @doc false
  def instrument_mod_clause(instrumenter, {:function, line, name, arg_count, body}) do
    instr_body = map(body, instrumenter, &instrument_body/2)
    {:function, line, name, arg_count, instr_body}
  end

  def instrument_mod_clause(_instrumenter, clause), do: clause

  # "Instruments the each body (a `:clause`) of a function"
  @doc false
  def instrument_body(instrumenter, {:clause, line, args, local_vars, exprs}) do
    instr_exprs = map_expr(exprs, instrumenter)
    {:clause, line, args, local_vars, instr_exprs}
  end

  # "This is a big switch over all kinds of expressions for instrumenting them"
  @doc false
  def instrument_expr(_instrumenter, a = {:atom, _, _}), do: a

  def instrument_expr(instrumenter, {:bc, line, expr, qs}) do
    {:bc, line, instrument_expr(instrumenter, expr),
     map(qs, instrumenter, &instrument_qualifier/2)}
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

  def instrument_expr(instrumenter, {:catch, line, expr}),
    do: {:catch, line, instrument_expr(instrumenter, expr)}

  def instrument_expr(instrumenter, {:cons, line, e1, e2}),
    do: {:cons, line, instrument_expr(instrumenter, e1), instrument_expr(instrumenter, e2)}

  def instrument_expr(instrumenter, {:fun, line, cs}) when is_list(cs) do
    {:fun, line, map(cs, instrumenter, &instrument_clause/2)}
  end

  def instrument_expr(_instrumenter, f = {:fun, _, _}), do: f

  def instrument_expr(instrumenter, c = {:call, _l, {:remote, _m, _f}, _args}),
    do: instrument_function_call(instrumenter, c)

  def instrument_expr(instrumenter, c = {:call, _l, _f, _args}),
    do: instrument_function_call(instrumenter, c)

  def instrument_expr(instrumenter, {:if, line, cs}),
    do: {:if, line, map(cs, instrumenter, &instrument_clause/2)}

  def instrument_expr(instrumenter, {:lc, line, e, qs}) do
    {:lc, line, instrument_expr(instrumenter, e), map(qs, instrumenter, &instrument_qualifier/2)}
  end

  def instrument_expr(instrumenter, {:map, line, assocs}),
    do: {:map, line, map(assocs, instrumenter, &instrument_assoc/2)}

  def instrument_expr(instrumenter, {:map, line, expr, assocs}) do
    {:map, line, instrument_expr(instrumenter, expr),
     map(assocs, instrumenter, &instrument_assoc/2)}
  end

  def instrument_expr(instrumenter, {:match, line, p, e}) do
    {:match, line, instrument_pattern(instrumenter, p), instrument_expr(instrumenter, e)}
  end

  def instrument_expr(_instrumenter, {nil, line}), do: {nil, line}

  def instrument_expr(instrumenter, {:op, line, op, e1}),
    do: {:op, line, op, instrument_expr(instrumenter, e1)}

  def instrument_expr(instrumenter, {:op, line, op, e1, e2}),
    do: {:op, line, op, instrument_expr(instrumenter, e1), instrument_expr(instrumenter, e2)}

  def instrument_expr(instrumenter, r = {:receive, _line, _cs}),
    do: instrument_receive(instrumenter, r)

  def instrument_expr(instrumenter, r = {:receive, _line, _cs, _e, _b}),
    do: instrument_receive(instrumenter, r)

  # record creation
  def instrument_expr(instrumenter, {:record, line, name, fields}) do
    {:record, line, name, map_expr(fields, instrumenter)}
  end

  # record update
  def instrument_expr(instrumenter, {:record, line, e, name, fields}) do
    {:record, line, instrument_expr(instrumenter, e), name, map_expr(fields, instrumenter)}
  end

  def instrument_expr(instrumenter, {:record_field, line, field, expr}),
    do: {:record, line, field, instrument_expr(instrumenter, expr)}

  def instrument_expr(instrumenter, {:record_field, line, expr, name, field}),
    do: {:record, line, instrument_expr(instrumenter, expr), name, field}

  def instrument_expr(_instrumenter, r = {:record_index, _line, _name, _fields}), do: r

  def instrument_expr(instrumenter, {:tuple, line, es}),
    do: {:tuple, line, map_expr(es, instrumenter)}

  def instrument_expr(instrumenter, {:try, line, body, cases, catches, expr}) do
    i_body = map_expr(body, instrumenter)
    i_cases = map(cases, instrumenter, &instrument_clause/2)
    i_catches = map(catches, instrumenter, &instrument_clause/2)
    {:try, line, i_body, i_cases, i_catches, instrument_expr(instrumenter, expr)}
  end

  def instrument_expr(_instrumenter, v = {:var, _l, _name}), do: v

  def instrument_expr(_instrumenter, l = {literal, _line, _val})
      when literal in [:atom, :integer, :float, :char, :string],
      do: l

  # "Instrument a part of binary pattern definition"
  @doc false
  def instrument_bin_element(instrumenter, {:bin_element, line, expr, size, tsl}) do
    {:bin_element, line, instrument_expr(instrumenter, expr), size, tsl}
  end

  # "Instrument case, catch, function clauses"
  @doc false
  def instrument_clause(instrumenter, {:clause, line, p, body}) do
    {:clause, line, instrument_pattern(instrumenter, p), map_expr(body, instrumenter)}
  end

  # def instrument_clause(instrumenter, {:clause, line, ps, body}) when is_list(ps) do
  #   {:clause, line, map_expr(ps, instrumenter), map_expr(body, instrumenter)}
  # end
  def instrument_clause(instrumenter, {:clause, line, ps, [guards], body})
      when is_list(ps) and is_list(guards) do
    {:clause, line, map_expr(ps, instrumenter), [map_expr(guards, instrumenter)],
     map_expr(body, instrumenter)}
  end

  def instrument_clause(instrumenter, {:clause, line, ps, guards, body}) when is_list(ps) do
    {:clause, line, map_expr(ps, instrumenter), map_expr(guards, instrumenter),
     map_expr(body, instrumenter)}
  end

  # "Instrument qualifiers of list and bit comprehensions"
  @doc false
  def instrument_qualifier(instrumenter, {:generate, line, p, e}),
    do: {:generate, line, instrument_pattern(instrumenter, p), instrument_expr(instrumenter, e)}

  def instrument_qualifier(instrumenter, {:b_generate, line, p, e}),
    do: {:b_generate, line, instrument_pattern(instrumenter, p), instrument_expr(instrumenter, e)}

  def instrument_qualifier(instrumenter, e), do: instrument_expr(instrumenter, e)

  # "Instrument patterns, which are mostly expressions, except for variables/atoms"
  @doc false
  # def instrument_pattern(instrumenter, {x, p, s}), do: {x, instrument_expr(instrumenter, p), s}
  def instrument_pattern(instrumenter, ps) when is_list(ps),
    do: map(ps, instrumenter, &instrument_pattern/2)

  def instrument_pattern(instrumenter, p), do: instrument_expr(instrumenter, p)

  @doc false
  def instrument_assoc(instrumenter, {assoc, line, key, value}) do
    {assoc, line, instrument_expr(instrumenter, key), instrument_expr(instrumenter, value)}
  end

  @doc false
  # """
  # Instruments a function call and gives control the handler module `instrumenter`.
  # For now, we only instrumenting a call, if it is any of the interesting functions,
  # i.e those might be a source of concurrency problems due to a shared mutable
  # state or otherwise tinkering with scheduling.
  # """
  def instrument_function_call(instrumenter, {:call, line, {:remote, line2, m, f}, as}) do
    module = instrument_expr(instrumenter, m)
    fun = instrument_expr(instrumenter, f)
    args = map_expr(as, instrumenter)

    case instrumenter.is_instrumentable_function(m, f) do
      true ->
        instrumenter.handle_function_call({:call, line, {:remote, line2, module, fun}, args})

      _ ->
        {:call, line, {:remote, line2, module, fun}, args}
    end
  end

  def instrument_function_call(instrumenter, {:call, line, f, as}) do
    fun = instrument_expr(instrumenter, f)
    args = map_expr(as, instrumenter)
    {:call, line, fun, args}
  end

  # "The receive might be handled differently, therefore it has its own function"
  @doc false
  def instrument_receive(instrumenter, {:receive, line, cs}) do
    {:receive, line, map(cs, instrumenter, &instrument_clause/2)}
  end

  def instrument_receive(instrumenter, {:receive, line, cs, e, b}) do
    {:receive, line, map(cs, instrumenter, &instrument_clause/2),
     instrument_expr(instrumenter, e), map_expr(b, instrumenter)}
  end

  @doc """
  Prepends the call to `to_be_wrapped_call` by a call to `new_call`.
  The result of `new_call` is ignored.

  All arugments and return values are in Erlang Astract Form.
  """
  @spec prepend_call(to_be_wrapped_call :: erl_ast_remote_call, new_call :: erl_ast_remote_call) ::
          erl_ast_block
  def prepend_call(to_be_wrapped_call, new_call) do
    {:block, [generated: true], [new_call, to_be_wrapped_call]}
  end

  @doc """
  Enocdes a call given as tuple `{m, f, a}` as Erlang Abstract Form.
  """
  @spec encode_call({m :: module(), f :: atom(), a :: list()}) :: erl_ast_remote_call
  def encode_call(_call = {m, f, a}) when is_atom(m) and is_atom(f) and is_list(a) do
    # [generated: true]
    line = 0

    {:call, line, {:remote, line, {:atom, line, m}, {:atom, line, f}},
     Enum.map(a, &encode_value/1)}
  end

  @doc "Encodes a call to `m.f.(a)` as Erlang Abstract Form."
  @spec encode_call(m :: module(), f :: atom(), a :: list()) :: erl_ast_remote_call
  def encode_call(m, f, a) when is_atom(m) and is_atom(f) and is_list(a),
    do: encode_call({m, f, a})

  @doc "Encodes a value as Erlang Astract Form."
  @spec encode_value(val :: any) :: :erl_parse.abstract_expr()
  def encode_value(nil), do: {nil, [generated: true]}
  def encode_value(value) when is_atom(value), do: {:atom, [generated: true], value}
  def encode_value(value) when is_integer(value), do: {:integer, [generated: true], value}
  def encode_value(value) when is_float(value), do: {:float, [generated: true], value}

  def encode_value(value) when is_binary(value),
    do:
      {:bin, [generated: true],
       [
         {:bin_element, [generated: true],
          {:string, [generated: true], String.to_charlist(value)}, :default, :default}
       ]}

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

  def encode_value(_unknown), do: throw(ArgumentError)

  @doc "Encodes a call to `:erlang.yield()` as Erlang Astract Form."
  @spec call_yield() :: erl_ast_remote_call
  def call_yield do
    encode_call({:erlang, :yield, []})
  end

  @doc """
  Debugging aid for analyzing code generations. Prints the restructered Erlang code of function
  `fun` in module `mod`. We use Erlang code here, because Elixir source code cannot generated from
  the byte code format due to macros, which change the compilation process too heavily.
  """
  @spec print_fun(fun :: atom(), mod :: module()) :: :ok
  def print_fun(fun, mod \\ __MODULE__) do
    {:ok, _filename, forms} = get_forms_of_module(mod)
    {:abstract_code, {:raw_abstract_v1, clauses}} = forms

    funs =
      Enum.filter(clauses, fn
        {:function, _, ^fun, _, _} -> true
        _ -> false
      end)

    case funs do
      [f] -> :erl_pp.function(f) |> IO.puts()
      [] -> IO.puts("Unknown function #{inspect(fun)}")
    end
  end

  @doc """
  Checks if the given function is a candidate for instrumentation, i.e. does something
  interesting with respect to concurrency. Examples are process handling, handling
  of shared state or sending and receiving messages.
  """
  @spec instrumentable_function({:atom, any, mod :: module()}, {:atom, any, fun :: atom}) ::
          boolean()
  # Generate the matcher for interestng functions by a macro. All these functions
  # are concerned with process handling, sending or receiving messages and handling
  # of shared state (in particular for :ets, Registry and the process dictionary)
  all_instrumentable_functions = [
    ets: :lookup,
    ets: :lookup_element,
    ets: :update_element,
    ets: :insert,
    ets: :insert_new,
    ets: :delete_object,
    ets: :delete,
    ets: :delete_all_objects,
    ets: :select_delete,
    ets: :match_delete,
    ets: :match_object,
    ets: :member,
    ets: :new,
    gen_server: :start_link,
    gen_server: :start,
    gen_server: :call,
    gen_server: :cast,
    gen_server: :server,
    gen_server: :loop,
    supervisor: :start_link,
    supervisor: :start_child,
    supervisor: :which_children,
    timer: :sleep,
    timer: :apply_after,
    timer: :exit_after,
    erlang: :spawn,
    erlang: :spawn_link,
    erlang: :link,
    erlang: :process_flag,
    # erlang: yield,
    erlang: :now,
    erlang: :is_process_alive,
    erlang: :demonitor,
    erlang: :monitor,
    erlang: :exit,
    gen_event: :start_link,
    gen_event: :send,
    gen_event: :add_handler,
    gen_event: :notify,
    gen_fsm: :start_link,
    gen_fsm: :send_event,
    gen_fsm: :send_all_state_event,
    gen_fsm: :sync_send_all_state_event,
    io: :format,
    file: :write_file,
    "Elixir.IO": :puts,
    "Elixir.GenServer": :start_link,
    "Elixir.GenServer": :start,
    "Elixir.GenServer": :call,
    "Elixir.GenServer": :cast,
    "Elixir.GenServer": :server,
    "Elixir.GenServer": :loop,
    "Elixir.Task": :start_link,
    "Elixir.Task": :start,
    "Elixir.Task": :call,
    "Elixir.Task": :cast,
    "Elixir.Task": :shutdown,
    "Elixir.Task": :async,
    "Elixir.Task": :await,
    "Elixir.Task": :async_stream,
    "Elixir.Task": :yield,
    "Elixir.Task": :yield_many,
    "Elixir.Supervisor": :start_link,
    "Elixir.Supervisor": :start_child,
    "Elixir.Supervisor": :restart_child,
    "Elixir.Supervisor": :stop,
    "Elixir.Supervisor": :count_children,
    "Elixir.Supervisor": :delete_child,
    "Elixir.Supervisor": :terminate_child,
    "Elixir.Supervisor": :which_children,
    "Elixir.DynamicSupervisor": :start_link,
    "Elixir.DynamicSupervisor": :start_child,
    "Elixir.DynamicSupervisor": :stop,
    "Elixir.DynamicSupervisor": :count_children,
    "Elixir.DynamicSupervisor": :delete_child,
    "Elixir.DynamicSupervisor": :terminate_child,
    "Elixir.DynamicSupervisor": :which_children,
    "Elixir.Agent": :start_link,
    "Elixir.Agent": :start,
    "Elixir.Agent": :cast,
    "Elixir.Agent": :stop,
    "Elixir.Agent": :get,
    "Elixir.Agent": :get_and_update,
    "Elixir.Agent": :update,
    "Elixir.Process": :delete_key,
    "Elixir.Process": :get,
    "Elixir.Process": :link,
    "Elixir.Process": :put,
    "Elixir.Process": :register,
    "Elixir.Process": :whereis,
    "Elixir.Registry": :start_link,
    "Elixir.Registry": :count_match,
    "Elixir.Registry": :count,
    "Elixir.Registry": :dispatch,
    "Elixir.Registry": :keys,
    "Elixir.Registry": :lookup,
    "Elixir.Registry": :match,
    "Elixir.Registry": :meta,
    "Elixir.Registry": :put_meta,
    "Elixir.Registry": :register,
    "Elixir.Registry": :select,
    "Elixir.Registry": :unregister_match,
    "Elixir.Registry": :unregister,
    "Elixir.Registry": :update_value,
    "Elixir.Task.Supervisor": :start_link,
    "Elixir.Task.Supervisor": :start_child,
    "Elixir.Task.Supervisor": :stop,
    "Elixir.Task.Supervisor": :terminate_child,
    "Elixir.Task.Supervisor": :async,
    "Elixir.Task.Supervisor": :async_nolink,
    "Elixir.Task.Supervisor": :async_stream,
    "Elixir.Task.Supervisor": :async_stream_nolink
  ]

  for {mod, fun} <- all_instrumentable_functions do
    # IO.puts "generate fun for #{inspect mod}.#{inspect fun}()"
    # This is an unquote fragment, no need for quote do ... end, designed for generating functions
    def instrumentable_function({:atom, _, unquote(mod)}, {:atom, _, unquote(fun)}), do: true
  end

  def instrumentable_function(_mod = {:atom, _, m}, _fun = {:atom, _, f})
      when is_atom(m) and is_atom(f),
      do: false

  # def instrumentable_function(mod, fun), do: false

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
