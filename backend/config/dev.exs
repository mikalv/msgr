import Config

listen_ip =
  System.get_env("PHX_LISTEN_IP", "127.0.0.1")
  |> String.split(".")
  |> Enum.reduce_while([], fn part, acc ->
    case Integer.parse(part) do
      {value, ""} when value in 0..255 -> {:cont, [value | acc]}
      _ -> {:halt, :error}
    end
  end)
  |> case do
    [d, c, b, a] -> {a, b, c, d}
    _ -> {127, 0, 0, 1}
  end

config :msgr, Messngr.Repo,
  username: System.get_env("POSTGRES_USERNAME", "postgres"),
  password: System.get_env("POSTGRES_PASSWORD", "postgres"),
  hostname: System.get_env("POSTGRES_HOST", "localhost"),
  database: "msgr_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

config :msgr, :noise,
  enabled: false,
  transport_port: 5_443,
  default_static_key: {:base64, "CI11hCvbZNQaeEW5Yt7ttmN09Sf+bNSNAXXfPn4f+vI="},
  env_var: "NOISE_STATIC_KEY",
  secret_field: "private"

config :msgr_web, MessngrWeb.Endpoint,
  http: [ip: listen_ip, port: String.to_integer(System.get_env("PORT", "4000"))],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "HyLhx8LdVFnH2MOu1U0sSjl0ZzRCDlXuTBQX6wYJvvM4A3Bd4cF8xWHXcEml0qCw",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:msgr_web, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:msgr_web, ~w(--watch)]}
  ]

config :msgr_web, MessngrWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/msgr_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

config :msgr_web, dev_routes: true
config :msgr_web, :expose_otp_codes, true
config :msgr_web, :noise_handshake_stub, enabled: true

shared_repo_dev_config = [
  username: System.get_env("POSTGRES_USERNAME", "postgres"),
  password: System.get_env("POSTGRES_PASSWORD", "postgres"),
  hostname: System.get_env("POSTGRES_HOST", "localhost"),
  database: System.get_env("POSTGRES_DB", "msgr_dev"),
  pool_size: String.to_integer(System.get_env("POSTGRES_POOL_SIZE", "10"))
]

config :auth_provider, AuthProvider.Repo, shared_repo_dev_config
config :teams, Teams.Repo, shared_repo_dev_config

config :logger, :console, format: "[$level] $message\n"

config :logger,
  backends: [:console, {Messngr.Logging.OpenObserveBackend, :openobserve_dev}]

openobserve_transport =
  case String.downcase(System.get_env("OPENOBSERVE_TRANSPORT", "http")) do
    "stonemq" -> :stonemq
    _ -> :http
  end

openobserve_queue_module =
  System.get_env("OPENOBSERVE_QUEUE_MODULE")
  |> case do
    nil -> nil
    "" -> nil
    module ->
      module
      |> String.split(".")
      |> Enum.map(&String.to_atom/1)
      |> Module.concat()
  end

openobserve_opts = [
  enabled: System.get_env("OPENOBSERVE_ENABLED", "false") == "true",
  endpoint: System.get_env("OPENOBSERVE_ENDPOINT", "http://openobserve:5080"),
  org: System.get_env("OPENOBSERVE_ORG", "default"),
  stream: System.get_env("OPENOBSERVE_STREAM", "backend"),
  dataset: System.get_env("OPENOBSERVE_DATASET", "_json"),
  username: System.get_env("OPENOBSERVE_USERNAME", "root@example.com"),
  password: System.get_env("OPENOBSERVE_PASSWORD", "Complexpass#123"),
  metadata: [:application, :module, :function, :line, :request_id, :pid],
  level: :debug,
  service: System.get_env("OPENOBSERVE_SERVICE", "msgr_backend_dev"),
  transport: openobserve_transport,
  queue_topic: System.get_env("OPENOBSERVE_QUEUE_TOPIC", "observability/logs"),
  queue_module: openobserve_queue_module
]

if Code.ensure_loaded?(Messngr.Logging.OpenObserveBackend) do
  config :messngr_logging, Messngr.Logging.OpenObserveBackend,
    default: [],
    openobserve_dev: openobserve_opts
end

config :msgr_web, :prometheus,
  enabled: true,
  port: String.to_integer(System.get_env("PROMETHEUS_PORT", "9568")),
  name: :prometheus_metrics_dev

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
