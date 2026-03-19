defmodule Messngr.Tenancy do
  @moduledoc """
  Custom tenancy module for multi-tenant schema management.

  Replaces Triplex with ~100 lines of hand-rolled tenant lifecycle.
  Each team gets a PostgreSQL schema named "tenant_<team_id>".
  """

  alias Messngr.Repo

  @doc """
  Creates a new tenant schema and runs all tenant migrations.
  Returns the schema name.
  """
  def create_tenant(team_id) do
    schema = "tenant_#{team_id}"
    Ecto.Adapters.SQL.query!(Repo, "CREATE SCHEMA IF NOT EXISTS \"#{schema}\"")
    migrate_tenant(schema)
    schema
  end

  @doc """
  Drops a tenant schema and all its objects.
  """
  def drop_tenant(team_id) do
    schema = "tenant_#{team_id}"
    Ecto.Adapters.SQL.query!(Repo, "DROP SCHEMA IF EXISTS \"#{schema}\" CASCADE")
  end

  @doc """
  Runs all pending tenant migrations for the given schema.
  """
  def migrate_tenant(schema) do
    Ecto.Migrator.run(Repo, tenant_migrations_path(), :up, prefix: schema, all: true)
  end

  @doc """
  Runs tenant migrations for every existing tenant schema.
  Intended for use in release tasks on deploy.
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
  Convenience for `Repo.all(Schema, prefix: Messngr.Tenancy.prefix(team_id))`.
  """
  def prefix(team_id), do: "tenant_#{team_id}"

  defp tenant_migrations_path do
    Application.app_dir(:teams, "priv/repo/tenant_migrations")
  end
end
