import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :teams, Teams.Repo,
  username: System.get_env("POSTGRES_USERNAME"),
  password: System.get_env("POSTGRES_PASSWORD"),
  hostname: "localhost",
  database: "teams_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

config :auth_provider, AuthProvider.Repo,
  username: System.get_env("POSTGRES_USERNAME"),
  password: System.get_env("POSTGRES_PASSWORD"),
  hostname: "localhost",
  database: "msgr_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2
# We don't run a server during test. If one is required,
# you can enable the server option below.
config :teams, TeamsWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "iqDpmPQG1NdTITwhe5CvyKv4O3tSvWQKKK057Jq9MSSfNZyXOa4Eae2lx0R+AYx4",
  server: false

config :auth_provider, :oauth_module, Boruta.OauthMock
config :auth_provider, :openid_module, Boruta.OpenidMock

# In test we don't send emails
config :teams, Teams.Mailer, adapter: Swoosh.Adapters.Test

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :slack_api, SlackApiWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "+VUKIdMrD85a9pqI782To04uvfEiHRs/rtWTcqrMoDVfhjhEwtQ+BwhyacHJWyZ3",
  server: false


# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :msgr, Messngr.Repo,
  username: System.get_env("POSTGRES_USERNAME"),
  password: System.get_env("POSTGRES_PASSWORD"),
  hostname: "localhost",
  database: "msgr_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :msgr_web, MessngrWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "ZHlVJIhuM+H2QkMdkk84VwtmlhLHAJ+o6HsLzxtLuj9cUi9EmZL9OHuTZ3xV9MFX",
  server: false

# Print only warnings and errors during test
config :logger, level: :warning

# In test we don't send emails
config :msgr, Messngr.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
