defmodule Teams.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring access to the application's
  data layer.

  Teams.Repo does **not** use the SQL Sandbox in test (see `config/test.exs`):
  tenant schema provisioning runs `Ecto.Migrator` (which spawns Tasks) and
  dual-repo sandbox ownership causes checkout deadlocks. Tests must use unique
  team UUIDs/slugs instead of relying on transaction rollback.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Teams.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Teams.DataCase
    end
  end

  setup _tags do
    :ok
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.
  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
