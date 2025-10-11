# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :teams,
  snowflake: [
    machine_id: 23,   # values are 0 thru 1023 nodes
    epoch: 1727306184
  ]

config :teams,
  ecto_hashids: [
    prefix_separator: ":",                         # What goes after the prefix?
    characters: "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghjkmnpqrstvwxyz", # Which characters should be valid for hashid
    salt: "fef04203-dead-b00b-b00b-1727306184",  # What do you want to use for a salt for creating hashids
    prefix_descriptions: %{
      P: Teams.TenantModels.Profile,
      M: Teams.TenantModels.Message,
      C: Teams.TenantModels.Conversation,
      R: Teams.TenantModels.Room,
      Q: Teams.TenantModels.Role,
      U: AuthProvider.Account.User,
      D: AuthProvider.Account.Device,
      N: AuthProvider.Account.AuthMethod
    }
    ]

config :boruta, Boruta.Oauth,
  repo: AuthProvider.Repo,
  issuer: "https://auth.msgr.no",
  contexts: [
    resource_owners: AuthProvider.ResourceOwners
  ]

config :edge_router,
  http: [port: 4080],
  server: true,
  default_endpoint: MessngrWeb.Endpoint

config :triplex, repo: Teams.Repo, tenant_prefix: "tenant_team_"

config :oauth2, debug: true

config :oauth2, middleware: [
  Tesla.Middleware.Retry,
]

config :hammer,
  backend: {Hammer.Backend.ETS, [expiry_ms: 60_000 * 60 * 4,
                                 cleanup_interval_ms: 60_000 * 10]}

config :teams,
  ecto_repos: [Teams.Repo],
  generators: [timestamp_type: :utc_datetime]


default_hostname = System.get_env("PHX_HOST", "7f000001.nip.io")

# Configures the endpoint
config :auth_provider, AuthProvider.Endpoint,
  url: [host: "auth." <> default_hostname],
  render_errors: [
    formats: [html: AuthProvider.ErrorHTML, json: AuthProvider.ErrorJSON],
    layout: false
  ],
  pubsub_server: AuthProvider.PubSub,
  live_view: [signing_salt: "+Beg+g2c"]

# Configures the endpoint
config :teams, MessngrWeb.Endpoint,
  url: [host: "teams." <> default_hostname],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: MessngrWeb.ErrorHTML, json: MessngrWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Messngr.PubSub,
  live_view: [signing_salt: "+Beg+g2c"]

# Configures the endpoint
config :teams, TeamsWeb.Endpoint,
  url: [host: "teams." <> default_hostname],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: TeamsWeb.ErrorHTML, json: TeamsWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Teams.PubSub,
  live_view: [signing_salt: "+Beg+g2c"]

# Configures the endpoint
config :slack_api, SlackApiWeb.Endpoint,
  url: [host: "slack-api." <> default_hostname],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: SlackApiWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: SlackApi.PubSub,
  live_view: [signing_salt: "J1g4mKlx"]


# Configuration for mailer

config :slack_api, SlackApi.Mailer, adapter: Swoosh.Adapters.Local
config :teams, Teams.Mailer, adapter: Swoosh.Adapters.Local
config :msgr, Messngr.Mailer, adapter: Swoosh.Adapters.Local


#  dkim: [
#    s: "default", d: "domain.com",
#    private_key: {:pem_plain, File.read!("priv/keys/domain.private")}
#  ],




# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  auth_provider: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../apps/auth_provider/assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  auth_provider: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../apps/auth_provider/assets", __DIR__)
  ]

config :teams, Teams.Upload,
  bucket: System.get_env("AWS_S3_BUCKET"),
  region: System.get_env("AWS_S3_REGION"),
  access_key: System.get_env("AWS_ACCESS_KEY_ID"),
  secret: System.get_env("AWS_SECRET_ACCESS_KEY"),
  endpoint: System.get_env("AWS_S3_ENDPOINT")

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  teams: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../apps/teams/assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  teams: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../apps/teams/assets", __DIR__)
  ]


config :slack_api,
  generators: [timestamp_type: :utc_datetime]


# Configure Mix tasks and generators
config :msgr,
  namespace: Messngr,
  ecto_repos: [Messngr.Repo]


config :msgr_web,
  namespace: MessngrWeb,
  ecto_repos: [Messngr.Repo],
  generators: [context_app: :msgr]

config :auth_provider,
  namespace: AuthProvider,
  ecto_repos: [AuthProvider.Repo]
#
# TODO: Override this key in production
config :auth_provider, AuthProvider.Guardian,
  issuer: "Messngr",
  hooks: GuardianDb,
  ttl: { 30, :days },
  allowed_drift: 2000,
  verify_issuer: true,
  secret_key: "aA1klFBlrzosVHX0JKOVZYKNd0MrZz0kTwzDipTOg15tmzhStlPY3RH5XcoHuwCC"

config :guardian, Guardian.DB,
  # Add your repository module
  repo: AuthProvider.Repo,
  # default
  schema_name: "guardian_tokens",
  # store all token types if not set
  token_types: ["refresh_token"],
  # default: 60 minutes
  sweep_interval: 60


# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  msgr_web: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../apps/msgr_web/assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.4.3",
  msgr_web: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../apps/msgr_web/assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
