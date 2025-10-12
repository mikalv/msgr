defmodule AuthProvider.MixProject do
  use Mix.Project

  def project do
    [
      app: :auth_provider,
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

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {AuthProvider.Application, []},
      extra_applications: [:logger, :runtime_tools, :jose, :guardian]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.7.14"},
      {:phoenix_ecto, "~> 4.5"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_view, "~> 2.0"},
      {:phoenix_html_helpers, "~> 1.0"},
      # TODO bump on release to {:phoenix_live_view, "~> 1.0.0"},
      {:phoenix_live_view, "~> 1.0.0-rc.1", override: true},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:telemetry_metrics, ">= 0.6.0 and < 2.0.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.20"},
      {:msgr, in_umbrella: true},
      {:jason, "~> 1.2"},
      # Auth and DB stuff
      {:boruta, "~> 2.3"},
      {:ecto_sql, "~> 3.10"},
      {:postgrex, ">= 0.0.0"},
      {:guardian, "~> 2.3.2"},
      {:guardian_db, "~> 3.0"},
      {:hammer, "~> 6.2"},
      {:oauth2, "~> 2.1"},
      {:httpoison, "~> 2.2"},
      {:cors_plug, "~> 3.0"},
      # Development
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:esbuild, "~> 0.8", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
      # Tests
      {:mox, "~> 0.5", only: :test},
      {:excoveralls, "~> 0.14", only: :test},
      {:coverex, "~> 1.4", only: :test},
      {:ex_machina, "~> 2.6", only: :test},
      {:faker, "~> 0.14", only: :test},
      {:floki, ">= 0.30.0", only: :test},
      {:mock, "~> 0.3.8", only: :test}

    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "deps.compile", "assets.setup", "assets.build"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind msgr_web", "esbuild msgr_web"],
      "assets.deploy": [
        "tailwind msgr_web --minify",
        "esbuild msgr_web --minify",
        "phx.digest"
      ]
    ]
  end
end
