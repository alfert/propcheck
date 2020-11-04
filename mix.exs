defmodule PropCheck.Mixfile do
  @moduledoc "Buildfile for PropCheck"
  use Mix.Project

  @source_url "https://github.com/alfert/propcheck"
  @version "1.3.1-dev"

  def project do
    [
      app: :propcheck,
      version: @version,
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: Coverex.Task, console_log: true],
      package: package(),
      name: "PropCheck",
      homepage_url: @source_url,
      docs: [
        main: "readme",
        source_url: @source_url,
        source_ref: "v#{@version}",
        extras: ["README.md", "CHANGELOG.md"],
        extra_section: "Overview"
      ],
      description: description(),
      propcheck: [counter_examples: "_build/propcheck.ctx"],
      aliases: aliases(),
      preferred_cli_env: [
        tests: :test,
        test_ext: :test,
        dialyzer: :test,
        parallel_test: :test,
        test_parallel: :test
      ],
      deps: deps(),
      dialyzer: dialyzer()
    ]
  end

  defp description do
    """
    PropCheck provides property based testing and is an Elixir layer around
    PropEr. It is also inspired by Quviq's QuickCheck Elixir library.
    """
  end

  defp package do
    [
      maintainers: ["Klaus Alfert"],
      licenses: ["GPL 3.0"],
      links: %{"GitHub" => @source_url}
    ]
  end

  def application do
    [
      applications: [:logger, :proper, :libgraph],
      mod: {PropCheck.App, []},
      extra_applications: [:iex]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def aliases do
    [
      clean: ["clean", "propcheck.clean"],
      test_ext: &external_tests/1,
      parallel_test: ["test --include concurrency_test --only concurrency_test"],
      test_parallel: ["test --include concurrency_test --only concurrency_test"],
      tests: ["test_ext", "test"],
      lint: [
        "credo --strict",
        "hex.audit",
        "dialyzer"
      ]
    ]
  end

  defp deps do
    [
      {:proper, "~> 1.3"},
      {:libgraph, "~> 0.13"},
      {:coverex, "~> 1.4", only: :test},
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.21", only: :dev}
    ]
  end

  defp dialyzer do
    [
      plt_add_deps: :apps_direct,
      plt_add_apps: ~w(
        ex_unit
        iex
        mix
        compiler
      )a,
      flags: ~w(
        error_handling
        race_conditions
        unmatched_returns
        underspecs
      )a
    ]
  end

  defp external_tests(_args) do
    run = fn arg ->
      r = Mix.shell().cmd(arg)
      r > 0 && System.at_exit(fn _ -> exit({:shutdown, r}) end)
      r
    end

    run.("./test/verify_storing_counterexamples.sh")
    run.("./test/verify-verbose.sh")
    run.("./test/verify-detect-exceptions.sh")
    run.("./test/verify-verbose-in-elixir-syntax.sh")
  end
end
