defmodule AuthProvider.Repo do
  use Ecto.Repo,
    otp_app: :auth_provider,
    adapter: Ecto.Adapters.Postgres
end
