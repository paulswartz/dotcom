defmodule Vehicles.Mixfile do
  use Mix.Project

  def project do
    [
      app: :vehicles,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.3",
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
    [extra_applications: [:logger], mod: {Vehicles, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # To depend on another app inside the umbrella:
  #
  #   {:myapp, in_umbrella: true}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:v3_api, in_umbrella: true},
      {:repo_cache, in_umbrella: true},
      {:routes, in_umbrella: true},
      {:bypass, "~> 1.0", only: :test},
      {:phoenix_pubsub, "~> 1.0"},
      {:server_sent_event_stage, "~> 0.3"},
      {:gen_stage, "~> 0.13"},
      {:exvcr_helpers, in_umbrella: true, only: :test}
    ]
  end
end
