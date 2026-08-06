defmodule EdgeRouter.MixProject do
  use Mix.Project

  def project do
    [
      app: :edge_router,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [
        :logger
      ],
      mod: {EdgeRouter.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug_cowboy, ">= 2.6.0"},
      {:phoenix, "~> 1.7"},
      {:excoveralls, "~> 0.18", only: :test}
    ]
  end
end
