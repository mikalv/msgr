defmodule Teams.Reactions do
  @moduledoc """
  Context module for tenant-scoped reaction operations.
  """

  import Ecto.Query
  alias Teams.Repo

  @doc """
  Toggles a reaction on a message.
  If the reaction exists, removes it. Otherwise, adds it.
  """
  def toggle_reaction(prefix, message_id, profile_id, emoji) do
    query =
      from(r in {"reactions", Teams.TenantModels.Reaction},
        where: r.message_id == ^message_id and r.profile_id == ^profile_id and r.emoji == ^emoji
      )

    case Repo.one(query, prefix: prefix) do
      nil ->
        attrs = %{message_id: message_id, profile_id: profile_id, emoji: emoji}
        {1, _} = Repo.insert_all("reactions", [attrs], prefix: prefix)
        {:ok, attrs}

      existing ->
        Repo.delete(existing, prefix: prefix)
        {:ok, :removed}
    end
  end

  @doc """
  Lists all reactions for a message.
  """
  def list_reactions(prefix, message_id) do
    from(r in {"reactions", Teams.TenantModels.Reaction},
      where: r.message_id == ^message_id,
      order_by: [asc: r.emoji]
    )
    |> Repo.all(prefix: prefix)
  end
end
