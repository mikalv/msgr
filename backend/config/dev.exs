import Config


# Configure your database
config :auth_provider, AuthProvider.Repo,
  username: System.get_env("POSTGRES_USERNAME"),
  password: System.get_env("POSTGRES_PASSWORD"),
  hostname: "localhost",
  database: "msgr_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# Configure your database
config :teams, Teams.Repo,
  username: System.get_env("POSTGRES_USERNAME"),
  password: System.get_env("POSTGRES_PASSWORD"),
  hostname: "localhost",
  database: "teams_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# Configure your database
config :msgr, Messngr.Repo,
  username: System.get_env("POSTGRES_USERNAME"),
  password: System.get_env("POSTGRES_PASSWORD"),
  hostname: "localhost",
  database: "msgr_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we can use it
# to bundle .js and .css sources.

# Watch static and templates for browser reloading.
config :teams, TeamsWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/teams_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]


# Watch static and templates for browser reloading.
config :msgr_web, MessngrWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"priv/gettext/.*(po)$",
      ~r"lib/msgr_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]

# Watch static and templates for browser reloading.
config :auth_provider, AuthProvider.Endpoint,
live_reload: [
  patterns: [
    ~r"priv/static/(?!uploads/).*(js|css|png|jpeg|jpg|gif|svg)$",
    ~r"priv/gettext/.*(po)$",
    ~r"lib/auth_provider/(controllers|live|components)/.*(ex|heex)$"
  ]
]
# Enable dev routes for dashboard and mailbox
config :teams, dev_routes: true

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Enable dev routes for dashboard and mailbox
config :slack_api, dev_routes: true


# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we can use it
# to bundle .js and .css sources.

config :teams, TeamsWeb.Endpoint,
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "KkCacbOROtJIky1Ua1jsP3y5mrxd6Sm24QDz4eUiCgwQn24IGAIaMxRKtQUOgJyI",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:teams, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:teams, ~w(--watch)]}
  ]

config :msgr_web, MessngrWeb.Endpoint,
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "qwoyNQ1ugLHvds6ml4jYK4n8pDqngGDuhdaaOQOcTU3nbNRatQEx3NLZ0aNhbjJQ",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:msgr_web, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:msgr_web, ~w(--watch)]}
  ]


config :slack_api, SlackApiWeb.Endpoint,
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "qNrctCYCmpwRTD0jUXPMxTq6LPBFp4mvKbX08Lje/p0JZYvtwGm28ZVk1HnLHGAM",
  watchers: []


config :auth_provider, AuthProvider.Endpoint,
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "qwoyNQ1ugLHvds6ml4jYK4n8pDqngGDuhdaaOQOcTU3nbNRatQEx3NLZ0aNhbjJQ",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:msgr_web, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:msgr_web, ~w(--watch)]}
  ]


# Enable dev routes for dashboard and mailbox
config :msgr_web, dev_routes: true

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  # Include HEEx debug annotations as HTML comments in rendered markup
  debug_heex_annotations: true,
  # Enable helpful, but potentially expensive runtime checks
  enable_expensive_runtime_checks: true

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20
