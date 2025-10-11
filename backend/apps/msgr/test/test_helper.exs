{:ok, _} = Application.ensure_all_started(:mox)

ExUnit.start()

try do
  Ecto.Adapters.SQL.Sandbox.mode(Messngr.Repo, :manual)
rescue
  _ -> :ok
end
