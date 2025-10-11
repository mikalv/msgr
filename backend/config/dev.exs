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

config :logger, :console, format: "[$level] $message\n"

config :phoenix, :stacktrace_depth, 20
config :phoenix, :plug_init_mode, :runtime
