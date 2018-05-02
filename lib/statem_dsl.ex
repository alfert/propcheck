defmodule PropCheck.StateM.DSL do


  use PropCheck
  require Logger

  @type symbolic_state :: any
  @type dynamic_state :: any
  @type state_t :: symbolic_state | dynamic_state
  @type symbolic_var :: {:var, pos_integer}
  @type symbolic_call :: {:call, module, atom, [any]}
  @type command :: {:set, symbolic_var, symbolic_call}
  @type history_element :: {dynamic_state, any}
  @type result_t :: {:ok, any} | {:pre_condition, any} | {:post_condition, any} |
    {:exception, any}
  @type gen_fun_t :: (state_t -> PropCheck.BasicTypes.type)
  @type cmd_t ::
      {:args, module, String.t, atom, gen_fun_t} |
      {:cmd, module, String.t, gen_fun_t}

  @type t :: %__MODULE__{
    history: [history_element],
    state: state_t,
    result: result_t
  }
  defstruct [
    history: [],
    state: nil,
    result: :ok
  ]

  @callback initial_state() :: symbolic_state
  @callback weight(symbolic_state, symbolic_call) :: pos_integer
  @optional_callbacks weight: 2


  defmacro __using__(_options) do
    quote do
      import unquote(__MODULE__)
      Module.register_attribute __MODULE__, :commands, accumulate: true
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def __all_commands__(), do: @commands
    end
  end

  @known_suffixes [:pre, :post, :args, :next]
  defmacro command(name, do: block) do
    pre  = String.to_atom("#{name}_pre")
    next = String.to_atom("#{name}_next")
    post = String.to_atom("#{name}_post")
    args = String.to_atom("#{name}_args")
    quote do
      def unquote(pre)(_state, _call), do: true
      def unquote(next)(state, _call, _result), do: state
      def unquote(post)(_state, _call, _res), do: true
      def unquote(args)(_state), do: fixed_list([])
      defoverridable [{unquote(pre), 2}, {unquote(next), 3},
        {unquote(post), 3}, {unquote(args), 1}]
      @commands Atom.to_string(unquote(name))
      unquote(Macro.postwalk(block, &rename_def_in_command(&1, name)))
    end
  end

  def rename_def_in_command({:def, c1, [{:impl, c2, impl_args}, impl_body]}, name) do
      # Logger.error "Found impl with body #{inspect impl_body}"
    {:def, c1, [{name, c2, impl_args}, impl_body]}
  end
  def rename_def_in_command({:def, c1, [{suffix_name, c2, args}, body]}, name)
    when suffix_name in @known_suffixes
    do
      new_name = String.to_atom("#{name}_#{suffix_name}")
      # Logger.error "Found suffix: #{new_name}"
      {:def, c1,[{new_name, c2, args}, body]}
    end
  def rename_def_in_command(ast, _name) do
    # Logger.warn "Found ast = #{inspect ast}"
    ast
  end

  @doc """
  Generates the command list for the given module
  """
  @spec commands(module, binary) :: :proper_types.type()
  def commands(mod, bin_module \\ "") do
    cmd_list = command_list(mod, bin_module)
    # Logger.debug "commands:  cmd_list = #{inspect cmd_list}"
    gen_commands(mod, cmd_list)
  end

  @spec gen_commands(module, [cmd_t]) :: :proper_types.type()
  def gen_commands(mod, cmd_list) do
    initial_state = mod.initial_state()
    gen_cmd = sized(size, gen_cmd_list(size, cmd_list, mod, initial_state, 1))
    such_that cmds <- gen_cmd, when: is_valid(mod, initial_state, cmds)
  end

  # TODO: How is this function to be defined?
  def is_valid(mod, initial_state, cmds) do
    true
  end

  @doc """
  The internally used recursive generator for the command list
  """
  @spec gen_cmd_list(pos_integer, [cmd_t], module, state_t, pos_integer) :: PropCheck.BasicTypes.type
  def gen_cmd_list(0, _cmd_list, _mod, _state, _step_counter), do: exactly([])
  def gen_cmd_list(size, cmd_list, mod, state, step_counter) do
    # Logger.debug "gen_cmd_list: cmd_list = #{inspect cmd_list}"
    cmds_with_args = cmd_list
    |> Enum.map(fn {:cmd, _mod, _f, arg_fun} -> arg_fun.(state) end)
    # |> fn l ->
    #   Logger.debug("gen_cmd_list: call list is #{inspect l}")
    #   l end.()
    cmds = if :erlang.function_exported(mod, :weight, 2) do
      freq_cmds(cmds_with_args, state, mod)
    else
      oneof(cmds_with_args)
    end

    let call <-
      (such_that c <- cmds, when: check_precondition(state, c))
      do
        gen_result = {:var, step_counter}
        gen_state = call_next_state(state, call, gen_result)
        let cmds <- gen_cmd_list(size - 1, cmd_list, mod, gen_state, step_counter + 1) do
          [{state, {:set, gen_result, call}} | cmds]
        end
      end
  end

  def freq_cmds(cmd_list, state, mod) do
    cmd_list
    |> Enum.map(fn c = {:call, _m, f, _a} ->
      {mod.weight(state, f), c}
    end)
    |> frequency()
  end

  ###
  # implement run_commands
  #
  ###
  @spec run_commands([command]) :: t
  def run_commands(commands) do
    commands
    |> Enum.reduce(%__MODULE__{}, fn
      # do nothing if a failure occured
      _cmd, acc = %__MODULE__{result: r} when r != :ok -> acc
      # execute the next command
      cmd, acc ->
        cmd
        |> execute_cmd()
        |> update_history(acc)
    end)
  end

  @spec execute_cmd({state_t, command}) :: {state_t, symbolic_call, result_t}
  def execute_cmd({state, {:set, {:var, _}, c = {:call, m, f, args}}}) do
    result = if check_precondition(state, c) do
      try do
        result = apply(m, f, args)
        if check_postcondition(state, c, result) do
          {:ok, result}
        else
          {:post_condition, result}
        end
      rescue exc -> {:exception, exc}
      catch
        value -> {:exception, value}
        kind, value -> {:exception, {kind, value}}
      end
    else
      {:pre_condition, state}
    end
    {state, c, result}
  end

  def update_history(event = {s, _, r}, %__MODULE__{history: h}) do
    {code, _result_value} = r
    %__MODULE__{state: s, result: code, history: [event | h]}
  end

  @spec call_next_state(state_t, symbolic_call, any) :: state_t
  def call_next_state(state, {:call, mod, f, args}, result) do
    next_fun = (Atom.to_string(f) <> "_next")
      |> String.to_atom
    apply(mod, next_fun, [state, args, result])
  end

  @spec check_preconditions([{state_t, symbolic_call}]) :: boolean
  def check_preconditions(list) do
    Enum.all?(list, fn {state, call} -> check_precondition(state, call) end)
  end

  @spec check_precondition(state_t, symbolic_call) :: boolean
  def check_precondition(state, {:call, mod, f, args}) do
    pre_fun = (Atom.to_string(f) <> "_pre") |> String.to_atom
    apply(mod, pre_fun, [state, args])
  end

  @spec check_postcondition(state_t, symbolic_call, any) :: any
  def check_postcondition(state,  {:call, mod, f, args}, result) do
    post_fun = (Atom.to_string(f) <> "_post") |> String.to_atom
    apply(mod, post_fun, [state, args, result])
  end

  def command_names(cmds) do
    cmds
    |> Enum.map(fn {_state, {:set, _var, {:call, m, f, args}}} ->
      # "#{m}.#{f}/#{length(args)}"
      {m, f, length(args)}
    end)
  end


  @doc """
  Detects alls commands within `mod_bin_code`, i.e. all functions with the
  same prefix and a suffix `_command` or `_args` and a prefix `_next`.
  """
  @spec command_list(module, binary) :: [{:cmd, module, String.t, (state_t -> symbolic_call)}]
  def command_list(mod, "") do
    mod
    |> find_commands()
    |> Enum.map(fn {cmd, _arity} ->
      args_fun = fn state -> apply(mod, String.to_atom(cmd <> "_args"), [state]) end
      args = gen_call(mod, String.to_atom(cmd), args_fun)
      {:cmd, mod, cmd, args}
    end)
  end
  def command_list(mod, mod_bin_code) do
    {^mod, all_funs} = all_functions(mod_bin_code)
    cmd_impls = find_commands(mod_bin_code)

    cmd_impls
    |> Enum.map(fn {cmd, _arity} ->
      if find_fun(all_funs, "_args", [1]) do
        args_fun = fn state -> apply(mod, String.to_atom(cmd <> "_args"), [state]) end
        args = gen_call(mod, String.to_atom(cmd), args_fun)
        {:cmd, mod, cmd, args}
      else
        {:cmd, mod, cmd, & apply(mod, String.to_atom(cmd <> "_command"), &1)}
      end
    end)
  end

  @doc """
  Generates a function, which expects a state to create the call tuple
  with constants for module and function and an argument generator.
  """
  def gen_call(mod, fun, arg_fun) when is_atom(fun) and is_function(arg_fun, 1) do
    fn state ->  {:call, mod, fun, arg_fun.(state)} end
  end


  @spec find_fun([{String.t, arity}], String.t, [arity]) :: boolean
  def find_fun(all, suffix, arities) do
    all
    |> Enum.find_index(fn {f, a} ->
      a in arities and String.ends_with?(f, suffix)
    end)
    |> is_integer()
  end

  @spec find_commands(binary|module) :: [{String.t, arity}]
  def find_commands(mod) when is_atom(mod), do:
    mod.__all_commands__() |> Enum.map(& ({&1, 0}))
  def find_commands(mod_bin_code) do
    {_mod, funs} = all_functions(mod_bin_code)

    next_funs = funs
    |> Stream.filter(fn {f, a} ->
      String.ends_with?(f, "_next") and (a in [3,4]) end)
    |> Stream.map(fn {f, _a} -> String.replace_suffix(f, "_next", "") end)
    |> MapSet.new()

    funs
    |> Enum.filter(fn {f, _a} ->
      MapSet.member?(next_funs, f)
    end)
  end

  @spec all_functions(binary) :: {module, [{String.t, arity}]}
  def all_functions(mod_bin_code) do
    {:ok, {mod, [{:exports, functions}]}} = :beam_lib.chunks(mod_bin_code, [:exports])
    funs = Enum.map(functions, fn {f, a} -> {Atom.to_string(f), a} end)
    {mod, funs}
  end

end
