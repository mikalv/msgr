defmodule MessngrWeb.TeamReadCursorController do
  use MessngrWeb, :controller

  import Ecto.Query

  alias Teams.TeamManagement
  alias Teams.TenantModels.{ReadCursor, Message}

  action_fallback MessngrWeb.FallbackController

  @doc "GET /api/teams/:slug/unread_counts — unread count per channel"
  def index(conn, _params) do
    prefix = conn.assigns.tenant_prefix
    account = conn.assigns.current_account
    profile = TeamManagement.get_profile_for_account(prefix, account.id)

    unless profile do
      {:error, :forbidden}
    else
      cursors = ReadCursor.cursors_for_profile(prefix, profile.id)
      cursor_map = Map.new(cursors, fn c -> {c.channel_id, c.last_read_message_id} end)

      # Get all channels the user is a member of
      channels =
        from(c in Teams.TenantModels.Channel, select: c.id)
        |> Teams.Repo.all(prefix: prefix)

      counts =
        Enum.map(channels, fn channel_id ->
          count =
            case Map.get(cursor_map, channel_id) do
              nil ->
                # Never read — count all messages
                from(m in Message,
                  where: m.channel_id == ^channel_id and is_nil(m.thread_parent_id) and is_nil(m.deleted_at),
                  select: count(m.id)
                )
                |> Teams.Repo.one(prefix: prefix) || 0

              last_msg_id ->
                # Count messages after the last read one
                last_msg = Teams.Repo.get(Message, last_msg_id, prefix: prefix)
                if last_msg do
                  from(m in Message,
                    where: m.channel_id == ^channel_id
                      and is_nil(m.thread_parent_id)
                      and is_nil(m.deleted_at)
                      and m.inserted_at > ^last_msg.inserted_at,
                    select: count(m.id)
                  )
                  |> Teams.Repo.one(prefix: prefix) || 0
                else
                  0
                end
            end

          {channel_id, count}
        end)
        |> Enum.reject(fn {_, c} -> c == 0 end)
        |> Map.new()

      json(conn, %{data: counts})
    end
  end

  @doc "PUT /api/teams/:slug/channels/:channel_id/read_cursor — mark channel as read"
  def update(conn, %{"channel_id" => channel_id} = params) do
    prefix = conn.assigns.tenant_prefix
    account = conn.assigns.current_account
    last_read_message_id = params["last_read_message_id"]

    unless last_read_message_id do
      {:error, :bad_request}
    else
      profile = TeamManagement.get_profile_for_account(prefix, account.id)

      unless profile do
        {:error, :forbidden}
      else
        case ReadCursor.upsert(prefix, %{
               channel_id: channel_id,
               profile_id: profile.id,
               last_read_message_id: last_read_message_id
             }) do
          {:ok, cursor} ->
            json(conn, %{
              data: %{
                channel_id: cursor.channel_id,
                profile_id: cursor.profile_id,
                last_read_message_id: cursor.last_read_message_id
              }
            })

          {:error, changeset} ->
            {:error, changeset}
        end
      end
    end
  end
end
