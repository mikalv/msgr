import Config

config :msgr,
  ecto_repos: [Messngr.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

config :msgr, Messngr.Mailer,
  adapter: Swoosh.Adapters.Local

config :msgr, Messngr.Media.Storage,
  bucket: System.get_env("MEDIA_BUCKET", "msgr-media"),
  endpoint: System.get_env("MEDIA_ENDPOINT", "http://localhost:9000"),
  public_endpoint: System.get_env("MEDIA_PUBLIC_ENDPOINT")

config :msgr, Messngr.Media,
  upload_ttl_seconds: String.to_integer(System.get_env("MEDIA_UPLOAD_TTL", "900"))

host = System.get_env("PHX_HOST", "localhost")

config :msgr_web, MessngrWeb.Endpoint,
  url: [host: host],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: MessngrWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Messngr.PubSub,
  live_view: [signing_salt: "Zy8hKc6P"]

config :esbuild,
  version: "0.17.11",
  msgr_web: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../apps/msgr_web/assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

config :tailwind,
  version: "3.4.3",
  msgr_web: [
    args: ~w(--config=tailwind.config.js --input=css/app.css --output=../priv/static/assets/app.css),
    cd: Path.expand("../apps/msgr_web/assets", __DIR__)
  ]

config :phoenix, :json_library, Jason

config :swoosh, :api_client, false

config :msgr_web, :expose_otp_codes, false

config :logger, :console,
  format: "[$level] $message",
  metadata: [:request_id]

config :phoenix, :stacktrace_depth, 20

config :phoenix, :plug_init_mode, :runtime
