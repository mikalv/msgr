import Config
require Logger

if System.get_env("PHX_SERVER") do
  config :msgr_web, MessngrWeb.Endpoint, server: true
end

env = config_env()

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

default_db =
  case env do
    :prod -> "msgr_prod"
    _ -> "msgr_dev"
  end

shared_repo_config = [
  username: System.get_env("POSTGRES_USERNAME", "postgres"),
  password: System.get_env("POSTGRES_PASSWORD", "postgres"),
  hostname: System.get_env("POSTGRES_HOST", "localhost"),
  database: System.get_env("POSTGRES_DB", default_db),
  port: String.to_integer(System.get_env("POSTGRES_PORT", "5432")),
  ssl: String.downcase(System.get_env("POSTGRES_SSL", "false")) == "true"
]

config :msgr, Messngr.Repo, shared_repo_config
config :teams, Teams.Repo, shared_repo_config
config :auth_provider, AuthProvider.Repo, shared_repo_config

secret_key =
  case System.get_env("SECRET_KEY_BASE") do
    nil when env in [:dev, :test] ->
      Base.encode16(:crypto.strong_rand_bytes(32))

    nil ->
      raise "SECRET_KEY_BASE environment variable is missing."

    value ->
      value
  end

listen_ip =
  case System.get_env("PHX_LISTEN_IP", "127.0.0.1") do
    ip_string when is_binary(ip_string) ->
      ip_string
      |> String.split(".")
      |> Enum.map(&String.to_integer/1)
      |> List.to_tuple()
    _ ->
      {127, 0, 0, 1}
  end

config :msgr_web, MessngrWeb.Endpoint,
  http: [
    # Bind address controlled by PHX_LISTEN_IP env var (default: 127.0.0.1)
    # In Docker, set PHX_LISTEN_IP=0.0.0.0 to allow external access
    ip: listen_ip,
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

# Noise configuration removed - now handled by Rust gateway
# noise_config = Application.get_env(:msgr, :noise, [])

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

# MinIO / S3 configuration for ExAws
minio_host = System.get_env("MINIO_HOST", "localhost")
minio_port = port_env.(System.get_env("MINIO_PORT"), 9000, "MINIO_PORT")
minio_scheme = System.get_env("MINIO_SCHEME", "http://")
minio_public_host = System.get_env("MINIO_PUBLIC_HOST", "localhost")
minio_public_port = port_env.(System.get_env("MINIO_PUBLIC_PORT"), minio_port, "MINIO_PUBLIC_PORT")
minio_public_scheme = System.get_env("MINIO_PUBLIC_SCHEME", minio_scheme)

config :ex_aws,
  access_key_id: System.get_env("MINIO_ROOT_USER", "minioadmin"),
  secret_access_key: System.get_env("MINIO_ROOT_PASSWORD", "minioadmin"),
  region: "us-east-1",
  json_codec: Jason

config :ex_aws, :s3,
  scheme: minio_scheme,
  host: minio_host,
  port: minio_port,
  force_path_style: true

config :msgr, Messngr.Media.Storage,
  media_storage_config
  |> Keyword.put(:bucket, System.get_env("MINIO_BUCKET", Keyword.get(media_storage_config, :bucket, "msgr-media")))
  |> Keyword.put(:public_endpoint,
    case {minio_public_scheme, minio_public_port} do
      {"https://", 443} -> "https://#{minio_public_host}"
      {"http://", 80} -> "http://#{minio_public_host}"
      _ -> "#{minio_public_scheme}#{minio_public_host}:#{minio_public_port}"
    end)
  |> Keyword.put(:internal_endpoint, "#{minio_scheme}#{minio_host}:#{minio_port}")

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

# Noise configuration removed - now handled by Rust gateway
# All Noise transport and key management is done in the Rust gateway service
# which communicates with Elixir via gRPC

# DevHandshake configuration removed - part of Noise which is now in Rust gateway

guardian_secret =
  case System.get_env("GUARDIAN_SECRET_KEY") do
    nil when env in [:dev, :test] ->
      Base.encode16(:crypto.strong_rand_bytes(32))

    nil ->
      raise "GUARDIAN_SECRET_KEY environment variable is missing."

    value ->
      value
  end

config :auth_provider, AuthProvider.Guardian,
  issuer: "msgr",
  secret_key: guardian_secret

guardian_schema = System.get_env("GUARDIAN_DB_SCHEMA", "guardian_tokens")
guardian_interval_minutes =
  System.get_env("GUARDIAN_DB_SWEEP_MINUTES", "60")
  |> String.trim()
  |> case do
    "" -> 60
    value -> String.to_integer(value)
  end

config :guardian, Guardian.DB,
  repo: Messngr.Repo,
  schema_name: guardian_schema,
  sweep_interval: :timer.minutes(guardian_interval_minutes)

# OTP codes are NEVER exposed in API responses.
# They are delivered exclusively via email (SMTP) or SMS (BulkSMS).

# Prism search engine
config :teams, :prism_url, System.get_env("PRISM_URL", "http://localhost:3080")

# Bot authentication secret (for headless bot clients)
config :msgr_web, :bot_auth_secret, blank_to_nil.(System.get_env("BOT_AUTH_SECRET"))

if bool_env.(System.get_env("SWOOSH_LOCAL_ADAPTER"), false) do
  config :msgr, Messngr.Mailer, adapter: Swoosh.Adapters.Local
  config :swoosh, :api_client, false
else
  smtp_host = blank_to_nil.(System.get_env("SMTP_HOST"))

  if smtp_host do
    smtp_port = port_env.(System.get_env("SMTP_PORT"), 587, "SMTP_PORT")
    smtp_username = System.get_env("SMTP_USERNAME", "")
    smtp_password = System.get_env("SMTP_PASSWORD", "")

    config :msgr, Messngr.Mailer,
      adapter: Swoosh.Adapters.SMTP,
      relay: smtp_host,
      port: smtp_port,
      username: smtp_username,
      password: smtp_password,
      tls: :always,
      ssl: false,
      auth: :always,
      no_mx_lookups: true,
      tls_options: [verify: :verify_none]
  end
end

# BulkSMS configuration for phone OTP delivery
bulksms_username = blank_to_nil.(System.get_env("BULKSMS_USERNAME"))

if bulksms_username do
  config :msgr, Messngr.Auth.Notifier,
    sms_adapter: Messngr.Auth.Notifier.BulkSmsAdapter,
    email_sender: {"Msgr", System.get_env("SMTP_FROM", "noreply@msgr.no")}

  config :msgr, Messngr.Auth.Notifier.BulkSmsAdapter,
    username: bulksms_username,
    password: System.get_env("BULKSMS_PASSWORD", ""),
    sender_id: System.get_env("BULKSMS_SENDER_ID", "Msgr")
else
  config :msgr, Messngr.Auth.Notifier,
    email_sender: {"Msgr", System.get_env("SMTP_FROM", "noreply@msgr.no")}
end
