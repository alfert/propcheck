defmodule PropCheck.Mixfile do
  @moduledoc "Buildfile for PropCheck"
  use Mix.Project

  @source_url "https://github.com/alfert/propcheck"
  @version "1.4.2-dev"

  def project do
    [
      app: :propcheck,
      version: @version,
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      test_coverage: [threshold: 0.58],
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
        external_tests: :test,
        parallel_test: :test,
        test_parallel: :test
      ],
      deps: deps()
    ]
  end

  # Hex Package description
  defp description do
    """
    PropCheck provides property based testing and is an Elixir layer around
    PropEr. It is also inspired by Quviq's QuickCheck Elixir library.
    """
  end

  # Hex Package definition
  defp package do
    [
      maintainers: ["Klaus Alfert"],
      licenses: ["GPL 3.0"],
      links: %{"GitHub" => @source_url}
    ]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [
      applications: [:logger, :proper, :libgraph],
      mod: {PropCheck.App, []},
      extra_applications: [:iex]
    ]
  end

  # Specifies which paths to compile per environment
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def aliases do
    [
      clean: ["clean", "propcheck.clean"],
      external_tests: &external_tests/1,
      parallel_test: ["test --include concurrency_test --only concurrency_test"],
      test_parallel: ["test --include concurrency_test --only concurrency_test"],
      tests: [&loglevel/1, "external_tests", "test"],
      lint: [
        "credo --strict",
        "hex.audit"
      ]
    ]
  end

  defp deps do
    [
      {:proper, github: "proper-testing/proper", ref: "a5ae5669f01143b0828fc21667d4f5e344aa760b"},
      {:libgraph, "~> 0.13"},
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.21", only: :dev}
    ]
  end

  defp loglevel(_args) do
    log_level = System.get_env("LOG_LEVEL", "info") |> String.to_atom()
    Logger.configure(level: log_level)
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
