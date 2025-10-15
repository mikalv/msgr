import Config

config :msgr, Messngr.Repo,
  username: System.get_env("POSTGRES_USERNAME", "postgres"),
  password: System.get_env("POSTGRES_PASSWORD", "postgres"),
  hostname: System.get_env("POSTGRES_HOST", "localhost"),
  database: "msgr_test",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

config :msgr, :feature_flags, noise_handshake_required: false
config :msgr, :dns_cluster_query, :ignore

config :msgr, :llm_client, Messngr.AI.LlmClientMock

config :msgr_web, MessngrWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "35HSZsAA2kXtd6n2f9v+VRhNdScqD8Z+oF0dP6PbIapZF+8h9J0vXdyE3u/Bq5rC",
  server: false

config :logger, level: :warning

config :msgr_web, :expose_otp_codes, true
config :msgr_web, :noise_handshake_stub, enabled: true

config :phoenix, :plug_init_mode, :runtime

noise_private_key = :crypto.hash(:sha256, "msgr-noise-test-key")
{noise_public_key, _} = :crypto.generate_key(:ecdh, :x25519, noise_private_key)

fingerprint =
  noise_public_key
  |> then(&:crypto.hash(:blake2b, &1))
  |> binary_part(0, 32)
  |> Base.encode16(case: :lower)

config :msgr, :noise,
  enabled: true,
  private_key: noise_private_key,
  public_key: noise_public_key,
  protocol: "Noise_NX_25519_ChaChaPoly_Blake2b",
  prologue: "msgr-noise/v1",
  fingerprint: fingerprint,
  transport_port: 5_443

config :msgr, :noise_session_registry, enabled: false

config :msgr, Messngr.Noise.DevHandshake,
  enabled: true,
  allow_without_transport: false

config :msgr, Messngr.Chat.WatcherPruner, enabled: false

shared_repo_config =
  [
    username: System.get_env("POSTGRES_USERNAME", "postgres"),
    password: System.get_env("POSTGRES_PASSWORD", "postgres"),
    hostname: System.get_env("POSTGRES_HOST", "localhost"),
    database: System.get_env("POSTGRES_DB", "msgr_test"),
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: 5
  ]

config :auth_provider, AuthProvider.Repo, shared_repo_config
config :teams, Teams.Repo, shared_repo_config

config :auth_provider, AuthProvider.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4003],
  secret_key_base: "W6j5IuB0T7wC2nL1vF9YgR8sK3pQ4xM5zE6cV7bN8hJ0rT1yU2aI3oP4lS5dF6",
  server: false

config :teams, TeamsWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4004],
  secret_key_base: "N6v5rT4yU3iO2pL1kJ0hG9fD8sA7lK6jH5gF4dS3aP2oI1uY0tR9eW8qV7zX6",
  server: false

config :slack_api, SlackApiWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4005],
  secret_key_base: "P9oI8uY7tR6eW5qV4zX3cV2bN1mL0kJ9hG8fD7sA6lK5jH4gF3dS2aP1oI0u",
  server: false

config :llm_gateway,
  http_client: LlmGateway.HTTPClientMock,
  team_resolver: {LlmGateway.TestTeamResolver, []},
  system_credentials: %{}
