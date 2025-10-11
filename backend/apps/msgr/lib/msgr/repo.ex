defmodule Messngr.Repo do
  use Ecto.Repo,
    otp_app: :msgr,
    adapter: Ecto.Adapters.Postgres
end
