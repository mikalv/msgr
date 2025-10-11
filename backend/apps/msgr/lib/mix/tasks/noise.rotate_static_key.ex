defmodule Mix.Tasks.Noise.RotateStaticKey do
  @moduledoc """
  Generates a new static Curve25519 key pair for the Noise transport layer and
  prints the relevant metadata to STDOUT. The private key is printed only when
  `--print-private` is supplied.

  The command is intended for operations when rotating the server's static
  Noise key. Output is suitable for storing in environment variables or Secrets
  Manager.
  """

  use Mix.Task
  require Logger

  @shortdoc "Generates and logs a new Noise static key pair"

  @switches [print_private: :boolean, json: :boolean]

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.config")

    {opts, _, _} = OptionParser.parse(args, switches: @switches)

    {private_key, public_key} = generate_key_pair()
    fingerprint = Messngr.Noise.KeyLoader.fingerprint(private_key)
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    base_payload = %{
      protocol: Messngr.Noise.KeyLoader.protocol(),
      prologue: Messngr.Noise.KeyLoader.prologue(),
      static_public_key: Base.encode64(public_key),
      fingerprint: fingerprint,
      rotated_at: DateTime.to_iso8601(now)
    }

    payload =
      if opts[:print_private] do
        Map.put(base_payload, :static_private_key, Base.encode64(private_key))
      else
        base_payload
      end

    Logger.metadata(fingerprint: fingerprint)
    Logger.info("Generated new Noise static key")

    if opts[:json] do
      payload
      |> Jason.encode!(pretty: true)
      |> Mix.shell().info()
    else
      Mix.shell().info("Fingerprint: #{fingerprint}")
      Mix.shell().info("Protocol: #{payload.protocol}")
      Mix.shell().info("Prologue: #{payload.prologue}")
      Mix.shell().info("Public (base64): #{payload.static_public_key}")
      Mix.shell().info("Rotated at: #{payload.rotated_at}")

      unless opts[:print_private] do
        Mix.shell().info("Private key omitted. Re-run with --print-private to output it.")
      else
        Mix.shell().info("Private (base64): #{payload.static_private_key}")
      end

      Mix.shell().info("Export example: NOISE_STATIC_KEY=#{Base.encode64(private_key)}")
    end
  end

  defp generate_key_pair do
    case :enoise_keypair.new(:dh25519) do
      {:ok, _type, private_key, public_key} -> {private_key, public_key}
      {:enoise_keypair, _type, private_key, public_key} -> {private_key, public_key}
      other -> raise "Unsupported keypair format: #{inspect(other)}"
    end
  end
end
