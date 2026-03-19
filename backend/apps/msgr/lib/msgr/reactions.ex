defmodule Messngr.Reactions do
  @moduledoc """
  Context module for tenant-scoped reaction operations.
  """

  alias Teams.TenantModels.Reaction

  @doc """
  Toggles a reaction on a message.

  If the reaction (message_id + profile_id + emoji) exists, removes it.
  Otherwise, adds it. Returns `{:ok, reaction}` on add or `{:ok, :removed}` on remove.
  """
  def toggle_reaction(prefix, message_id, profile_id, emoji) do
    case Reaction.toggle(prefix, %{
           message_id: message_id,
           profile_id: profile_id,
           emoji: emoji
         }) do
      {:ok, %Reaction{} = reaction} -> {:ok, reaction}
      {:ok, _deleted} -> {:ok, :removed}
      error -> error
    end
  end

  @doc """
  Lists all reactions for a message.
  """
  def list_reactions(prefix, message_id) do
    Reaction.for_message(prefix, message_id)
  end
end
