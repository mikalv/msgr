import Config

config :msgr,
  ecto_repos: [Messngr.Repo],
  generators: [timestamp_type: :utc_datetime, binary_id: true]

config :msgr, :feature_flags, noise_handshake_required: true

config :msgr, Messngr.Mailer, adapter: Swoosh.Adapters.Local
config :msgr, Messngr.Auth.Notifier,
  email_sender: {"Messngr", System.get_env("MSGR_AUTH_EMAIL_FROM", "login@messngr.local")},
  sms_adapter: Messngr.Auth.Notifier.LogSmsAdapter

config :msgr, :rate_limits,
  auth_challenge: [limit: 5, period: :timer.minutes(10)],
  conversation_message_event: [limit: 60, period: :timer.minutes(1)]

config :msgr, :llm_client, Messngr.AI.LlmGatewayClient

config :msgr, :secrets_manager, Messngr.Secrets.Aws

media_sse_algorithm =
  case System.get_env("MEDIA_SSE_ALGORITHM", "AES256") do
    "" -> nil
    value -> value
  end

media_sse_kms_key_id =
  case System.get_env("MEDIA_SSE_KMS_KEY_ID") do
    nil -> nil
    "" -> nil
    value -> value
  end

share_link_segments =
  System.get_env("SHARE_LINK_PATH_SEGMENTS", "links")
  |> String.split("/", trim: true)
  |> case do
    [] -> ["links"]
    segments -> segments
  end

config :msgr, Messngr.Media.Storage,
  bucket: System.get_env("MEDIA_BUCKET", "msgr-media"),
  endpoint: System.get_env("MEDIA_ENDPOINT", "http://localhost:9000"),
  public_endpoint: System.get_env("MEDIA_PUBLIC_ENDPOINT"),
  signing_secret: System.get_env("MEDIA_SIGNING_SECRET", "dev-secret"),
  upload_expiry_seconds: String.to_integer(System.get_env("MEDIA_UPLOAD_EXPIRY", "600")),
  download_expiry_seconds: String.to_integer(System.get_env("MEDIA_DOWNLOAD_EXPIRY", "1200")),
  server_side_encryption: media_sse_algorithm,
  sse_kms_key_id: media_sse_kms_key_id

config :msgr, Messngr.Media,
  upload_ttl_seconds: String.to_integer(System.get_env("MEDIA_UPLOAD_TTL", "900")),
  retention_ttl_seconds: String.to_integer(System.get_env("MEDIA_RETENTION_TTL", "604800"))

config :msgr, Messngr.ShareLinks,
  public_base_url: System.get_env("SHARE_LINK_PUBLIC_BASE_URL", "https://msgr.no"),
  public_path: System.get_env("SHARE_LINK_PUBLIC_PATH", "/s"),
  msgr_scheme: System.get_env("SHARE_LINK_SCHEME", "msgr"),
  msgr_host: System.get_env("SHARE_LINK_HOST", "share"),
  msgr_path_segments: share_link_segments

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
    args:
      ~w(--config=tailwind.config.js --input=css/app.css --output=../priv/static/assets/app.css),
    cd: Path.expand("../apps/msgr_web/assets", __DIR__)
  ]

config :phoenix, :json_library, Jason

config :swoosh, :api_client, false

config :msgr_web, :expose_otp_codes, false

config :logger, :console,
  format: "[$level] $message",
  metadata: [:request_id]

config :logger, backends: [:console]

config :msgr_web, :prometheus,
  enabled: false,
  port: 9568,
  name: :prometheus_metrics

config :messngr_logging, Messngr.Logging.OpenObserveBackend,
  default: [
    enabled: false,
    endpoint: "http://localhost:5080",
    org: "default",
    stream: "backend",
    dataset: "_json",
    username: "root@example.com",
    password: "Complexpass#123",
    metadata: [:application, :module, :function, :line, :request_id, :pid],
    level: :info,
    service: "msgr_backend"
  ]

config :phoenix, :stacktrace_depth, 20

config :phoenix, :plug_init_mode, :runtime

config :hammer,
  backend:
    {Hammer.Backend.ETS,
     [expiry_ms: :timer.minutes(10), cleanup_interval_ms: :timer.minutes(1)]}

config :llm_gateway,
  default_provider: :openai,
  default_model: "gpt-4o-mini",
  http_client: LlmGateway.HTTP,
  team_resolver: {LlmGateway.TeamKeyResolver.Noop, []},
  providers: %{
    openai: [
      module: LlmGateway.Provider.OpenAI,
      base_url: "https://api.openai.com/v1",
      required_credentials: [:api_key]
    ],
    azure_openai: [
      module: LlmGateway.Provider.AzureOpenAI,
      endpoint:
        System.get_env("AZURE_OPENAI_ENDPOINT", "https://example-resource.openai.azure.com"),
      deployment: System.get_env("AZURE_OPENAI_DEPLOYMENT", "gpt-4o"),
      api_version: System.get_env("AZURE_OPENAI_API_VERSION", "2024-05-01-preview"),
      required_credentials: [:api_key]
    ],
    google_vertex: [
      module: LlmGateway.Provider.GoogleVertex,
      endpoint: "https://generativelanguage.googleapis.com",
      required_credentials: [:api_key]
    ],
    openai_compatible: [
      module: LlmGateway.Provider.OpenAI,
      base_url: System.get_env("SELF_HOSTED_OPENAI_URL", "https://openrouter.ai/api/v1"),
      required_credentials: [:api_key]
    ]
  },
  system_credentials: %{
    openai: %{api_key: System.get_env("OPENAI_API_KEY")},
    azure_openai: %{api_key: System.get_env("AZURE_OPENAI_API_KEY")},
    google_vertex: %{api_key: System.get_env("GOOGLE_VERTEX_API_KEY")},
    openai_compatible: %{api_key: System.get_env("SELF_HOSTED_OPENAI_KEY")}
  }

import_config "#{config_env()}.exs"
