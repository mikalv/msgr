ExUnit.start()

try do
  Ecto.Adapters.SQL.Sandbox.mode(Messngr.Repo, :manual)
rescue
  _ -> :ok
end
