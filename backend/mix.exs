defmodule Messngr.Umbrella.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      releases: [
        chatd: [
          applications: [
            msgr: :permanent,
            msgr_web: :permanent
          ],
          include_executables_for: [:unix]
        ]
      ]
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
  # Type "mix help deps" for more examples and options.
  #
  # Dependencies listed here are available only for this project
  # and cannot be accessed from applications inside the apps/ folder.
  defp deps do
    [
      # Required to run "mix format" on ~H/.heex files from the umbrella root
      # TODO bump on release to {:phoenix_live_view, ">= 0.0.0"},
      {:phoenix_live_view, "~> 1.0.0-rc.1", override: true},
      {:gen_smtp, "~> 1.3", override: true},
      {:decibel, "~> 0.2.4", override: true},
      {:ex_json_schema, "~> 0.11.1", override: true},
      {:castle, "~> 0.3.0", runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  #
  # Aliases listed here are available only for this project
  # and cannot be accessed from applications inside the apps/ folder.
  defp aliases do
    [
      setup: [
        "deps.get",
        "cmd --app auth_provider mix setup",
        "cmd --app msgr mix setup",
        "cmd --app msgr_web mix setup"
      ]
    ]
  end

end
