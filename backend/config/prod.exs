import Config

config :msgr, Messngr.Repo,
  pool_size: String.to_integer(System.get_env("POOL_SIZE", "10"))

config :logger, level: :info
