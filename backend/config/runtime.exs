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

tls_enabled =
  bool_env.(
    System.get_env("MSGR_TLS_ENABLED"),
    false
  )

tls_force_ssl =
  bool_env.(
    System.get_env("MSGR_FORCE_SSL"),
    false
  )

tls_force_ssl_hsts =
  bool_env.(
    System.get_env("MSGR_FORCE_SSL_HSTS"),
    false
  )

if tls_enabled do
  certfile =
    case blank_to_nil.(System.get_env("MSGR_TLS_CERT_PATH")) do
      nil -> raise "MSGR_TLS_CERT_PATH must be set when MSGR_TLS_ENABLED=true"
      value -> value
    end

  keyfile =
    case blank_to_nil.(System.get_env("MSGR_TLS_KEY_PATH")) do
      nil -> raise "MSGR_TLS_KEY_PATH must be set when MSGR_TLS_ENABLED=true"
      value -> value
    end

  cacertfile = blank_to_nil.(System.get_env("MSGR_TLS_CACERT_PATH"))

  tls_port =
    port_env.(
      System.get_env("MSGR_TLS_PORT"),
      4_443,
      "MSGR_TLS_PORT"
    )

  https_opts =
    [
      port: tls_port,
      cipher_suite: :strong,
      certfile: certfile,
      keyfile: keyfile
    ]

  https_opts =
    if cacertfile do
      Keyword.put(https_opts, :cacertfile, cacertfile)
    else
      https_opts
    end

  force_ssl_opts =
    if tls_force_ssl do
      [rewrite_on: [:x_forwarded_proto], hsts: tls_force_ssl_hsts]
    else
      false
    end

  config :msgr_web, MessngrWeb.Endpoint,
    https: https_opts,
    force_ssl: force_ssl_opts
else
  if tls_force_ssl do
    Logger.warning("MSGR_FORCE_SSL=true but MSGR_TLS_ENABLED=false; skipping force_ssl configuration")
  end
end

noise_config = Application.get_env(:msgr, :noise, [])

bool_env = fn
  nil, default -> default
  value, _default -> String.downcase(value) in ["1", "true", "yes", "on"]
end

blank_to_nil = fn
  nil -> nil
  "" -> nil
  value -> value
end

port_env = fn
  nil, default, _env_name -> default
  "", default, _env_name -> default
  value, _default, env_name ->
    case Integer.parse(value) do
      {port, ""} -> port
      _ -> raise "#{env_name} must be an integer"
    end
end

int_env = fn
  nil, default, _env_name -> default
  "", default, _env_name -> default
  value, _default, env_name ->
    case Integer.parse(value) do
      {int, ""} -> int
      _ -> raise "#{env_name} must be an integer"
    end
end

prometheus_config = Application.get_env(:msgr_web, :prometheus, [])

prometheus_enabled =
  bool_env.(
    System.get_env("PROMETHEUS_ENABLED"),
    Keyword.get(prometheus_config, :enabled, true)
  )

prometheus_port =
  port_env.(
    System.get_env("PROMETHEUS_PORT"),
    Keyword.get(prometheus_config, :port, 9_568),
    "PROMETHEUS_PORT"
  )

config :msgr_web, :prometheus,
  prometheus_config
  |> Keyword.put(:enabled, prometheus_enabled)
  |> Keyword.put(:port, prometheus_port)

media_storage_config = Application.get_env(:msgr, Messngr.Media.Storage, [])

media_signing_secret =
  case blank_to_nil.(System.get_env("MEDIA_SIGNING_SECRET")) do
    nil ->
      case blank_to_nil.(Keyword.get(media_storage_config, :signing_secret)) do
        nil when env in [:dev, :test] -> "dev-secret"
        nil ->
          raise "MEDIA_SIGNING_SECRET environment variable is missing."

        secret -> secret
      end

    secret -> secret
  end

config :msgr, Messngr.Media.Storage,
  Keyword.put(media_storage_config, :signing_secret, media_signing_secret)

retention_pruner_config = Application.get_env(:msgr, Messngr.Media.RetentionPruner, [])

pruner_enabled =
  bool_env.(
    System.get_env("MEDIA_RETENTION_SWEEP_ENABLED"),
    Keyword.get(retention_pruner_config, :enabled, true)
  )

pruner_interval =
  int_env.(
    System.get_env("MEDIA_RETENTION_SWEEP_INTERVAL_MS"),
    Keyword.get(retention_pruner_config, :interval_ms, :timer.minutes(10)),
    "MEDIA_RETENTION_SWEEP_INTERVAL_MS"
  )

pruner_batch_size =
  int_env.(
    System.get_env("MEDIA_RETENTION_SWEEP_BATCH_SIZE"),
    Keyword.get(retention_pruner_config, :batch_size, 100),
    "MEDIA_RETENTION_SWEEP_BATCH_SIZE"
  )

config :msgr, Messngr.Media.RetentionPruner,
  retention_pruner_config
  |> Keyword.put(:enabled, pruner_enabled)
  |> Keyword.put(:interval_ms, pruner_interval)
  |> Keyword.put(:batch_size, pruner_batch_size)

watcher_pruner_config = Application.get_env(:msgr, Messngr.Chat.WatcherPruner, [])

watcher_pruner_enabled =
  bool_env.(
    System.get_env("CONVERSATION_WATCHER_SWEEP_ENABLED"),
    Keyword.get(watcher_pruner_config, :enabled, true)
  )

watcher_pruner_interval =
  int_env.(
    System.get_env("CONVERSATION_WATCHER_SWEEP_INTERVAL_MS"),
    Keyword.get(watcher_pruner_config, :interval_ms, :timer.minutes(1)),
    "CONVERSATION_WATCHER_SWEEP_INTERVAL_MS"
  )

config :msgr, Messngr.Chat.WatcherPruner,
  watcher_pruner_config
  |> Keyword.put(:enabled, watcher_pruner_enabled)
  |> Keyword.put(:interval_ms, watcher_pruner_interval)

noise_enabled =
  bool_env.(
    System.get_env("NOISE_TRANSPORT_ENABLED"),
    Keyword.get(noise_config, :enabled, false)
  )

noise_port =
  port_env.(
    System.get_env("NOISE_TRANSPORT_PORT"),
    Keyword.get(noise_config, :transport_port, 5_443),
    "NOISE_TRANSPORT_PORT"
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

dev_handshake_config = Application.get_env(:msgr, Messngr.Noise.DevHandshake, [])

dev_handshake_enabled =
  bool_env.(
    System.get_env("NOISE_DEV_HANDSHAKE_ENABLED"),
    Keyword.get(dev_handshake_config, :enabled, false)
  )

dev_handshake_allow =
  bool_env.(
    System.get_env("NOISE_DEV_HANDSHAKE_ALLOW_DISABLED"),
    Keyword.get(dev_handshake_config, :allow_without_transport, false)
  )

config :msgr, Messngr.Noise.DevHandshake,
  dev_handshake_config
  |> Keyword.put(:enabled, dev_handshake_enabled)
  |> Keyword.put(:allow_without_transport, dev_handshake_allow)
