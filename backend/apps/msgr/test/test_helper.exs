{:ok, _} = Application.ensure_all_started(:mox)
{:ok, _} = Application.ensure_all_started(:hammer)
{:ok, _} = Application.ensure_all_started(:decibel)

{:ok, _} = Application.ensure_all_started(:msgr, permanent: false)

ExUnit.start()

try do
  Ecto.Adapters.SQL.Sandbox.mode(Messngr.Repo, :manual)
rescue
  _ -> :ok
end
