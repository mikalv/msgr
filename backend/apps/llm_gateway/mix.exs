defmodule LlmGateway.MixProject do
  use Mix.Project

  def project do
    [
      app: :llm_gateway,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      mod: {LlmGateway.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:finch, "~> 0.16"},
      {:jason, "~> 1.4"},
      {:mox, "~> 0.5", only: :test},
      {:telemetry, "~> 1.2"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get"]
    ]
  end
end
