defmodule MessngrWeb.TeamMessageController do
  use MessngrWeb, :controller

  alias Teams.Messages
  alias Teams.TeamManagement
  alias Teams.Pagination

  action_fallback MessngrWeb.FallbackController

  @doc "GET /api/teams/:slug/channels/:channel_id/messages — cursor-paginated messages"
  def index(conn, %{"channel_id" => channel_id} = params) do
    prefix = conn.assigns.tenant_prefix
    cursor_opts = Pagination.parse_params(params)

    {messages, meta} = Messages.list_messages(prefix, channel_id, cursor_opts)

    json(conn, %{
      data: Enum.map(messages, &message_json/1),
      meta: %{has_more: meta.has_more}
    })
  end

  @doc "POST /api/teams/:slug/channels/:channel_id/messages — send a message"
  def create(conn, %{"channel_id" => channel_id} = params) do
    prefix = conn.assigns.tenant_prefix
    account = conn.assigns.current_actor

    profile = TeamManagement.get_profile_for_account(prefix, account.id)

    unless profile do
      {:error, :forbidden}
    else
      attrs = %{
        channel_id: channel_id,
        sender_profile_id: profile.id,
        content: params["content"] || %{},
        thread_parent_id: params["thread_parent_id"],
        media_refs: params["media_refs"] || []
      }

      case Messages.create_message(prefix, attrs) do
        {:ok, message} ->
          message = Messages.get_message(prefix, message.id)

          conn
          |> put_status(:created)
          |> json(%{data: message_json(message)})

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  @doc "GET /api/teams/:slug/channels/:channel_id/threads/:message_id — get a thread"
  def thread(conn, %{"message_id" => message_id} = params) do
    prefix = conn.assigns.tenant_prefix
    cursor_opts = Pagination.parse_params(params)

    case Messages.get_thread(prefix, message_id, cursor_opts) do
      {:ok, %{parent: parent, replies: replies}} ->
        json(conn, %{
          data: %{
            parent: message_json(parent),
            replies: Enum.map(replies, &message_json/1)
          }
        })

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  defp message_json(message) do
    %{
      id: message.id,
      channel_id: message.channel_id,
      sender_profile_id: message.sender_profile_id,
      sender_profile: profile_json(message.sender_profile),
      thread_parent_id: message.thread_parent_id,
      content: message.content,
      media_refs: message.media_refs,
      edited_at: message.edited_at,
      inserted_at: message.inserted_at,
      reactions: reactions_json(message.reactions)
    }
  end

  defp profile_json(nil), do: nil

  defp profile_json(profile) do
    %{
      id: profile.id,
      display_name: profile.display_name,
      avatar_url: profile.avatar_url,
      role: profile.role
    }
  end

  defp reactions_json(nil), do: []

  defp reactions_json(reactions) when is_list(reactions) do
    reactions
    |> Enum.group_by(& &1.emoji)
    |> Enum.map(fn {emoji, rs} ->
      %{
        emoji: emoji,
        count: length(rs),
        profile_ids: Enum.map(rs, & &1.profile_id)
      }
    end)
  end

  defp reactions_json(_), do: []
end
