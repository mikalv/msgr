defmodule MessngrWeb.TeamChannelController do
  use MessngrWeb, :controller

  alias Teams.Channels
  alias Teams.TeamManagement

  action_fallback MessngrWeb.FallbackController

  @doc "GET /api/teams/:slug/channels — list channels"
  def index(conn, _params) do
    prefix = conn.assigns.tenant_prefix
    channels = Channels.list_channels(prefix)
    json(conn, %{data: Enum.map(channels, &channel_json/1)})
  end

  @doc "POST /api/teams/:slug/channels — create a channel"
  def create(conn, params) do
    prefix = conn.assigns.tenant_prefix
    account = conn.assigns.current_account

    profile = TeamManagement.get_profile_for_account(prefix, account.id)

    unless profile do
      {:error, :forbidden}
    else
      attrs = %{
        name: params["name"],
        icon: params["icon"],
        visibility: params["visibility"] || "public",
        topic: params["topic"],
        created_by: profile.id
      }

      case Channels.create_channel(prefix, attrs) do
        {:ok, channel} ->
          conn
          |> put_status(:created)
          |> json(%{data: channel_json(channel)})

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  defp channel_json(channel) do
    %{
      id: channel.id,
      name: channel.name,
      slug: channel.slug,
      icon: channel.icon,
      kind: channel.kind,
      visibility: channel.visibility,
      topic: channel.topic,
      inserted_at: channel.inserted_at
    }
  end
end
