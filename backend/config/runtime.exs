import Config
require Logger

if System.get_env("PHX_SERVER") do
  config :msgr_web, MessngrWeb.Endpoint, server: true
end

env = config_env()

default_db =
  case env do
    :prod -> "msgr_prod"
    _ -> "msgr_dev"
  end

config :msgr, Messngr.Repo,
  username: System.get_env("POSTGRES_USERNAME", "postgres"),
  password: System.get_env("POSTGRES_PASSWORD", "postgres"),
  hostname: System.get_env("POSTGRES_HOST", "localhost"),
  database: System.get_env("POSTGRES_DB", default_db),
  port: String.to_integer(System.get_env("POSTGRES_PORT", "5432")),
  ssl: String.downcase(System.get_env("POSTGRES_SSL", "false")) == "true"

secret_key =
  case System.get_env("SECRET_KEY_BASE") do
    nil when env in [:dev, :test] ->
      Base.encode16(:crypto.strong_rand_bytes(32))

    nil ->
      raise "SECRET_KEY_BASE environment variable is missing."

    value ->
      value
  end

config :msgr_web, MessngrWeb.Endpoint,
  http: [
    port: String.to_integer(System.get_env("PORT", "4000"))
  ],
  secret_key_base: secret_key,
  url: [
    host: System.get_env("PHX_HOST", "example.com"),
    port: String.to_integer(System.get_env("PHX_PORT", "443")),
    scheme: System.get_env("PHX_SCHEME", "https")
  ]

noise_config = Application.get_env(:msgr, :noise, [])

bool_env = fn
  nil, default -> default
  value, _default -> String.downcase(value) in ["1", "true", "yes", "on"]
end

port_env = fn
  nil, default -> default
  "", default -> default
  value, _default ->
    case Integer.parse(value) do
      {port, ""} -> port
      _ -> raise "NOISE_TRANSPORT_PORT must be an integer"
    end
end

noise_enabled =
  bool_env.(
    System.get_env("NOISE_TRANSPORT_ENABLED"),
    Keyword.get(noise_config, :enabled, false)
  )

noise_port =
  port_env.(
    System.get_env("NOISE_TRANSPORT_PORT"),
    Keyword.get(noise_config, :transport_port, 5_443)
  )

base_noise_config =
  noise_config
  |> Keyword.put(:enabled, noise_enabled)
  |> Keyword.put(:transport_port, noise_port)

config :msgr, :noise, base_noise_config

if noise_enabled do
  noise_opts =
    [
      env_var: Keyword.get(base_noise_config, :env_var, "NOISE_STATIC_KEY"),
      default: Keyword.get(base_noise_config, :default_static_key),
      secret_id:
        System.get_env("NOISE_STATIC_KEY_SECRET_ID") || Keyword.get(base_noise_config, :secret_id),
      secret_field:
        System.get_env("NOISE_STATIC_KEY_SECRET_FIELD") ||
          Keyword.get(base_noise_config, :secret_field),
      secret_region:
        System.get_env("NOISE_STATIC_KEY_SECRET_REGION") ||
          Keyword.get(base_noise_config, :secret_region)
    ]
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)

  noise_key_result = Messngr.Noise.KeyLoader.load(noise_opts)

  noise_private_key =
    case {noise_key_result, config_env()} do
      {{:ok, key}, _env} ->
        key

      {{:error, :no_default_key}, :dev} ->
        Logger.warning("Noise static key default missing in dev; generating ephemeral key")
        case :crypto.generate_key(:ecdh, :x25519) do
          {private, _public} -> private
          {:ok, {private, _public}} -> private
        end

      {{:error, reason}, env} when env in [:prod, :staging] ->
        raise "Noise static key could not be loaded: #{inspect(reason)}"

      {{:error, reason}, _env} ->
        Logger.warning("Noise static key unavailable, continuing without static key", reason: inspect(reason))
        nil
    end

  if noise_private_key do
    public_key = Messngr.Noise.KeyLoader.public_key(noise_private_key)
    fingerprint = Messngr.Noise.KeyLoader.fingerprint(noise_private_key)

    rotated_at =
      with value when is_binary(value) <- System.get_env("NOISE_STATIC_KEY_ROTATED_AT"),
           {:ok, timestamp, _} <- DateTime.from_iso8601(value) do
        timestamp
      else
        _ -> DateTime.utc_now()
      end

    Logger.info("Loaded Noise static key", fingerprint: fingerprint, port: noise_port)

    config :msgr, :noise,
      Keyword.merge(base_noise_config,
        private_key: noise_private_key,
        public_key: public_key,
        private_key_base64: Base.encode64(noise_private_key),
        public_key_base64: Base.encode64(public_key),
        fingerprint: fingerprint,
        protocol: Messngr.Noise.KeyLoader.protocol(),
        prologue: Messngr.Noise.KeyLoader.prologue(),
        rotated_at: rotated_at
      )
  end
else
  Logger.info("Noise transport disabled; skipping static key load", port: noise_port)
end
