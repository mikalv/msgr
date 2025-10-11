import Config

config :msgr, Messngr.Repo,
  username: System.get_env("POSTGRES_USERNAME", "postgres"),
  password: System.get_env("POSTGRES_PASSWORD", "postgres"),
  hostname: System.get_env("POSTGRES_HOST", "localhost"),
  database: "msgr_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :msgr_web, MessngrWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "35HSZsAA2kXtd6n2f9v+VRhNdScqD8Z+oF0dP6PbIapZF+8h9J0vXdyE3u/Bq5rC",
  server: false

config :logger, level: :warning

config :msgr_web, :expose_otp_codes, true

config :phoenix, :plug_init_mode, :runtime

config :llm_gateway,
  http_client: LlmGateway.HTTPClientMock,
  team_resolver: {LlmGateway.TestTeamResolver, []},
  system_credentials: %{}
