defmodule MessngrWeb.TeamReadCursorController do
  use MessngrWeb, :controller

  alias Teams.TeamManagement
  alias Teams.TenantModels.ReadCursor

  action_fallback MessngrWeb.FallbackController

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
