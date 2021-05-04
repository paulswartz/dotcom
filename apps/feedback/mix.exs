defmodule Feedback.Mixfile do
  use Mix.Project

  def project do
    [
      app: :feedback,
      version: "0.1.0",
      elixir: "~> 1.3",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: LcovEx, ignore_paths: ~w(test/)],
      deps: deps()
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [extra_applications: [:logger]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:poison, "~> 2.2", override: true},
      {:timex, ">= 2.0.0"},
      {:briefly, "~> 0.3"},
      {:lcov_ex, "~> 0.2", only: [:dev, :test], runtime: false},
      {:plug, "~> 1.7.2"},
      {:ex_aws, "~> 2.1.2"},
      {:ex_aws_ses, "~> 2.1.1"},
      {:mail, "~> 0.2"},
      {:exvcr_helpers, in_umbrella: true, only: :test}
    ]
  end
end
