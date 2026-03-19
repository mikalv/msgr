defmodule MessngrWeb.TeamReactionController do
  use MessngrWeb, :controller

  alias Messngr.Reactions
  alias Messngr.Teams

  action_fallback MessngrWeb.FallbackController

  @doc "POST /api/teams/:slug/channels/:channel_id/messages/:message_id/reactions — toggle reaction"
  def toggle(conn, %{"message_id" => message_id} = params) do
    prefix = conn.assigns.tenant_prefix
    account = conn.assigns.current_actor
    emoji = params["emoji"]

    unless emoji do
      {:error, :bad_request}
    else
      profile = Teams.get_profile_for_account(prefix, account.id)

      unless profile do
        {:error, :forbidden}
      else
        case Reactions.toggle_reaction(prefix, message_id, profile.id, emoji) do
          {:ok, :removed} ->
            json(conn, %{data: %{action: "removed", emoji: emoji, message_id: message_id}})

          {:ok, reaction} ->
            conn
            |> put_status(:created)
            |> json(%{data: %{action: "added", emoji: reaction.emoji, message_id: reaction.message_id}})

          {:error, changeset} ->
            {:error, changeset}
        end
      end
    end
  end
end
