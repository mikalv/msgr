# Tenant migrations redefine the same module names per schema provision.
Code.put_compiler_option(:ignore_module_conflict, true)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Messngr.Repo, :manual)
# Teams.Repo is not sandboxed in test (tenant migrator + dual-repo conflicts).
