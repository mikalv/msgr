defmodule Teams.Tenancy do
  @moduledoc """
  Tenant lifecycle management for multi-tenant schema isolation.

  Each team gets a PostgreSQL schema named "tenant_<team_id>".
  Tenant migrations live in priv/repo/tenant_migrations of the :teams app.
  """

  alias Teams.Repo

  @doc """
  Creates a new tenant schema and runs all tenant migrations.
  Returns the schema name.
  """
  def create_tenant(team_id) do
    schema = prefix(team_id)

    run_outside_sandbox(fn ->
      Ecto.Adapters.SQL.query!(Repo, "CREATE SCHEMA IF NOT EXISTS \"#{schema}\"")
      migrate_tenant(schema)
    end)

    schema
  end

  @doc """
  Drops a tenant schema and all its objects.
  """
  def drop_tenant(team_id) do
    schema = prefix(team_id)

    run_outside_sandbox(fn ->
      Ecto.Adapters.SQL.query!(Repo, "DROP SCHEMA IF EXISTS \"#{schema}\" CASCADE")
    end)
  end

  @doc """
  Runs all pending tenant migrations for the given schema.
  """
  def migrate_tenant(schema) do
    # Serialize migration module compilation — Ecto reloads the same module
    # names for every tenant schema, and concurrent loads race on Elixir 1.19.
    :global.trans({:teams_tenant_migrate, :global}, fn ->
      previous = Code.get_compiler_option(:ignore_module_conflict)
      Code.put_compiler_option(:ignore_module_conflict, true)

      try do
        Ecto.Migrator.run(Repo, tenant_migrations_path(), :up,
          prefix: schema,
          all: true,
          disable_migration_lock: true
        )
      after
        Code.put_compiler_option(:ignore_module_conflict, previous)
      end
    end)
  end

  # DDL/migrator work needs connections outside the test sandbox transaction.
  defp run_outside_sandbox(fun) do
    if Code.ensure_loaded?(Ecto.Adapters.SQL.Sandbox) and
         Repo.config()[:pool] == Ecto.Adapters.SQL.Sandbox do
      Ecto.Adapters.SQL.Sandbox.unboxed_run(Repo, fun)
    else
      fun.()
    end
  end

  @doc """
  Runs tenant migrations for every existing tenant schema.
  """
  def migrate_all_tenants do
    for schema <- list_tenants() do
      migrate_tenant(schema)
    end
  end

  @doc """
  Lists all tenant schema names (matching "tenant_%") in the database.
  """
  def list_tenants do
    %{rows: rows} =
      Ecto.Adapters.SQL.query!(
        Repo,
        "SELECT schema_name FROM information_schema.schemata WHERE schema_name LIKE 'tenant_%'"
      )

    Enum.map(rows, fn [name] -> name end)
  end

  @doc """
  Returns the prefix string for a given team id.
  """
  def prefix(team_id), do: "tenant_#{team_id}"

  defp tenant_migrations_path do
    Application.app_dir(:teams, "priv/repo/tenant_migrations")
  end
end
