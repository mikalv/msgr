{:ok, _} = Application.ensure_all_started(:mox)
case Application.ensure_all_started(:enacl) do
  {:ok, _} -> :ok
  {:error, _} -> :ok
end

case Application.ensure_all_started(:enoise) do
  {:ok, _} -> :ok
  {:error, _} -> :ok
end

{:ok, _} = Application.ensure_all_started(:msgr)

ExUnit.start()

try do
  Ecto.Adapters.SQL.Sandbox.mode(Messngr.Repo, :manual)
rescue
  _ -> :ok
end
