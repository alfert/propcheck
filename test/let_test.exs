defmodule PropCheck.Test.LetAndShrinks do
  use ExUnit.Case
  use PropCheck

  @tag will_fail: true
  property "a simple forall shrinks", [:verbose] do
    forall n <- integer(100, 1000) do
      n != 180
    end
  end

  def kilo_numbers() do
    let [num <- integer(1, 1000)] do
      num
    end
  end

  @tag will_fail: true
  property "a simple let shrinks", [:verbose, numtests: 1_000] do
    pred = fn k -> k < 700 end
    forall n <- kilo_numbers() do
      pred.(n)
    end
  end

  defmodule DSLShrinkTest do # shrinks properly
    use ExUnit.Case
    use PropCheck
    use PropCheck.StateM.DSL

    def initial_state(), do: %{}

    defcommand :equal do
      def impl(_number), do: :ok
      def args(_state), do: [integer(1, 1000)]
      def post(_state, [arg], :ok), do: arg != 800
      def next(model, [_arg], _ret), do: model
    end

    @tag will_fail: true
    property "a simple integer shrinks in SM DSL", [numtests: 1000] do
      forall cmds <- commands(__MODULE__) do
          events = run_commands(cmds)
          (events.result == :ok)
          |> when_fail(
              IO.puts """
              History: #{inspect events.history, pretty: true}
              State: #{inspect events.state, pretty: true}
              Env: #{inspect events.env, pretty: true}
              Result: #{inspect events.result, pretty: true}
              """)
          |> aggregate(command_names cmds)
      end
    end

  end

  defmodule DSLLetTest do # shrinks properly
    use ExUnit.Case
    use PropCheck
    use PropCheck.StateM.DSL

    def initial_state(), do: %{}

    defcommand :equal do
      def impl(_number), do: :ok
      def args(_state) do
        arg_generator = let num <- integer(1, 1000) do
          num
        end
        [arg_generator]
      end
      def post(_state, [arg], :ok), do: arg != 800
      def next(model, [_arg], _ret), do: model
    end

    @tag will_fail: true
    property "a simple let will shrink in SM DSL", [numtests: 1000] do
      forall cmds <- commands(__MODULE__) do
          events = run_commands(cmds)
          (events.result == :ok)
          |> when_fail(
              IO.puts """
              History: #{inspect events.history, pretty: true}
              State: #{inspect events.state, pretty: true}
              Env: #{inspect events.env, pretty: true}
              Result: #{inspect events.result, pretty: true}
              """)
          |> aggregate(command_names cmds)
      end
    end

  end

  defmodule LetStateMachineTest do # shrinks properly
    use ExUnit.Case
    use PropCheck
    use PropCheck.StateM

    def initial_state(), do: %{}

    def args() do
      let ([num <- integer(1, 1000)]) do
        [num]
      end
    end
    def command(_state) do
      oneof([
        {:call, __MODULE__, :impl, args()}
      ])
    end
    def impl(_), do: :ok
    def postcondition(_state, {:call, _mod, _fun, [arg]}, :ok), do: arg != 800
    def next_state(model, _ret, _arg), do: model
    def precondition(_state, _call), do: true

    @tag will_fail: true
    property "let shrinks in PropEr's native SM", [numtests: 1000] do
      forall cmds <- commands(__MODULE__) do
          {history, state, result} = run_commands(__MODULE__, cmds)
          (result == :ok)
          |> when_fail(
              IO.puts """
              History: #{inspect history, pretty: true}
              State: #{inspect state, pretty: true}
              Result: #{inspect result, pretty: true}
              """)
          |> aggregate(command_names cmds)
      end
    end

  end

  defmodule DSLLetShrinkTest do # does shrink properly
    use ExUnit.Case
    use PropCheck
    use PropCheck.StateM.DSL

    def initial_state(), do: %{}

    defcommand :equal do
      def impl(_number), do: :ok
      def args(_state) do
        let  ([num <- integer(1, 1000)]) do
           [num]
        end

      end
      def post(_state, [arg], :ok), do: arg != 800
      def next(model, [_arg], _ret), do: model
    end

    @tag will_fail: true
    property "a let with a list shrinks in SM DSL", [numtests: 1000] do
      forall cmds <- commands(__MODULE__) do
          events = run_commands(cmds)
          (events.result == :ok)
          |> when_fail(
              IO.puts """
              History: #{inspect events.history, pretty: true}
              State: #{inspect events.state, pretty: true}
              Env: #{inspect events.env, pretty: true}
              Result: #{inspect events.result, pretty: true}
              """)
          |> aggregate(command_names cmds)
      end
    end

  end


end
