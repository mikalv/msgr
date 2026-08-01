defmodule MessngrWeb.TeamReactionController do
  use MessngrWeb, :controller

  alias Teams.Channels
  alias Teams.Messages
  alias Teams.Reactions

  action_fallback MessngrWeb.FallbackController

  @doc "POST /api/teams/:slug/channels/:channel_id/messages/:message_id/reactions — toggle reaction"
  def toggle(conn, %{"channel_id" => channel_id, "message_id" => message_id} = params) do
    prefix = conn.assigns.tenant_prefix
    profile = conn.assigns.current_team_profile
    emoji = params["emoji"]

    with :ok <- require_emoji(emoji),
         :ok <- Channels.authorize_channel_access(prefix, channel_id, profile.id),
         {:ok, _message} <- Messages.get_message_in_channel(prefix, channel_id, message_id) do
      case Reactions.toggle_reaction(prefix, message_id, profile.id, emoji) do
        {:ok, :removed} ->
          json(conn, %{data: %{action: "removed", emoji: emoji, message_id: message_id}})

        {:ok, reaction} ->
          conn
          |> put_status(:created)
          |> json(%{
            data: %{action: "added", emoji: reaction.emoji, message_id: reaction.message_id}
          })

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  defp require_emoji(emoji) when is_binary(emoji) and emoji != "", do: :ok
  defp require_emoji(_), do: {:error, :bad_request}
end
