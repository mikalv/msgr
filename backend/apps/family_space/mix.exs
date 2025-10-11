defmodule FamilySpace.MixProject do
  use Mix.Project

  def project do
    [
      app: :family_space,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  defp deps do
    [
      {:ecto_sql, "~> 3.10"},
      {:msgr, in_umbrella: true}
    ]
  end
end
