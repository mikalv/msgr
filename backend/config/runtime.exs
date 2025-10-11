import Config

if System.get_env("PHX_SERVER") do
  config :msgr_web, MessngrWeb.Endpoint, server: true
end

config :msgr, Messngr.Repo,
  username: System.fetch_env!("POSTGRES_USERNAME"),
  password: System.fetch_env!("POSTGRES_PASSWORD"),
  hostname: System.get_env("POSTGRES_HOST", "localhost"),
  database: System.get_env("POSTGRES_DB", "msgr_prod"),
  port: String.to_integer(System.get_env("POSTGRES_PORT", "5432")),
  ssl: String.downcase(System.get_env("POSTGRES_SSL", "false")) == "true"

secret_key =
  System.get_env("SECRET_KEY_BASE") ||
    raise "SECRET_KEY_BASE environment variable is missing."

config :msgr_web, MessngrWeb.Endpoint,
  http: [
    port: String.to_integer(System.get_env("PORT", "4000")),
    transport_options: [socket_opts: [:inet6]]
  ],
  secret_key_base: secret_key,
  url: [
    host: System.get_env("PHX_HOST", "example.com"),
    port: String.to_integer(System.get_env("PHX_PORT", "443")),
    scheme: System.get_env("PHX_SCHEME", "https")
  ]
