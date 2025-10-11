defmodule Teams.Repo do
  use Ecto.Repo,
    otp_app: :teams,
    adapter: Ecto.Adapters.Postgres
end
