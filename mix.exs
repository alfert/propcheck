defmodule PropCheck.Mixfile do
  @moduledoc "Buildfile for PropCheck"
  use Mix.Project

  def project do
    [app: :propcheck,
     version: "1.2.1-dev",
     elixir: "~> 1.5",
     elixirc_paths: elixirc_paths(Mix.env),
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     test_coverage: [tool: Coverex.Task, console_log: true],
     package: package(),
     name: "PropCheck - Property Testing",
     source_url: "https://github.com/alfert/propcheck",
     homepage_url: "https://github.com/alfert/propcheck",
     docs: [main: "readme", extras: ["README.md", "CHANGELOG.md"], extra_section: "Overview"],
     description: description(),
     propcheck: [counter_examples: "_build/propcheck.ctx"],
     aliases: aliases(),
     preferred_cli_env: [tests: :test, test_ext: :test, dialyzer: :test],
     deps: deps(),
     dialyzer: dialyzer()]
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
    [maintainers: ["Klaus Alfert"],
     licenses: ["GPL 3.0"],
     links: %{"GitHub" => "https://github.com/alfert/propcheck"}
    ]
  end

  # Configuration for the OTP application
  #
  # Type `mix help compile.app` for more information
  def application do
    [applications: [:logger, :proper],
     mod: {PropCheck.App, []}]
  end

  # Specifies which paths to compile per environment
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  def aliases do
    [
      clean: ["clean", "propcheck.clean"],
      test_ext: &external_tests/1,
      tests: ["test_ext", "test"],
    ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type `mix help deps` for more examples and options
  defp deps do
    [
      {:proper, "~> 1.3"},
      {:coverex, "~> 1.4", only: :test},
      {:poison, "~> 3.0", only: :test},
      {:credo, "~> 1.1", only: [:dev, :test], runtime: false},
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
