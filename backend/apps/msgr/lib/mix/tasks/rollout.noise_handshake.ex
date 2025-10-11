defmodule Mix.Tasks.Rollout.NoiseHandshake do
  use Mix.Task

  @shortdoc "Toggles the Noise handshake requirement feature flag"

  @switches [enable: :boolean, disable: :boolean]

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    case OptionParser.parse(args, switches: @switches) do
      {opts, [], []} -> handle_opts(opts)
      _ -> print_usage()
    end
  end

  defp handle_opts(%{enable: true, disable: true}),
    do: Mix.raise("Provide either --enable or --disable, not both")

  defp handle_opts(%{enable: true}) do
    Messngr.FeatureFlags.put(:noise_handshake_required, true)
    Mix.shell().info("Noise handshake requirement enabled")
  end

  defp handle_opts(%{disable: true}) do
    Messngr.FeatureFlags.put(:noise_handshake_required, false)
    Mix.shell().info("Noise handshake requirement disabled")
  end

  defp handle_opts(_opts) do
    print_usage()
    status = if Messngr.FeatureFlags.require_noise_handshake?(), do: "enabled", else: "disabled"
    Mix.shell().info("Current status: #{status}")
  end

  defp print_usage do
    Mix.shell().info("Usage: mix rollout.noise_handshake --enable | --disable")
  end
end
