defmodule MessngrWeb.TeamChannelController do
  use MessngrWeb, :controller

  alias Teams.Channels
  alias Teams.TeamManagement

  action_fallback MessngrWeb.FallbackController

  @doc "GET /api/teams/:slug/channels — list channels visible to current user"
  def index(conn, _params) do
    prefix = conn.assigns.tenant_prefix
    account = conn.assigns.current_account

    channels =
      case TeamManagement.get_profile_for_account(prefix, account.id) do
        nil -> Channels.list_public_channels(prefix)
        profile -> Channels.list_channels_for_profile(prefix, profile.id)
      end

    # Preload memberships+profiles for DM channels (needed for display names)
    channels = Enum.map(channels, fn ch ->
      if ch.kind in ["dm", "group_dm"] do
        Teams.Repo.preload(ch, [memberships: :profile], prefix: prefix)
      else
        ch
      end
    end)

    # Fetch last message per channel in one query
    channel_ids = Enum.map(channels, & &1.id)
    last_messages = Channels.last_messages_for_channels(prefix, channel_ids)

    json(conn, %{data: Enum.map(channels, fn ch ->
      channel_json(ch) |> Map.put(:last_message, last_messages[ch.id])
    end)})
  end

  @doc "POST /api/teams/:slug/channels — create a channel"
  def create(conn, params) do
    prefix = conn.assigns.tenant_prefix
    account = conn.assigns.current_account

    profile = TeamManagement.get_profile_for_account(prefix, account.id)

    unless profile do
      {:error, :forbidden}
    else
      channel_slug = case params["channel_slug"] do
        s when is_binary(s) and s != "" -> s
        _ ->
          params["name"]
          |> to_string()
          |> String.downcase()
          |> String.replace(~r/[^a-z0-9]+/, "-")
          |> String.trim("-")
      end
      attrs = %{
        name: params["name"],
        slug: channel_slug,
        icon: params["icon"],
        visibility: params["visibility"] || "public",
        topic: params["topic"],
        created_by: profile.id
      }

      case Channels.create_channel(prefix, attrs) do
        {:ok, channel} ->
          # Add invited members (if any)
          member_ids = params["member_ids"]

          if is_list(member_ids) and member_ids != [] do
            # Filter out the creator (already added) and add the rest
            extra_ids = Enum.reject(member_ids, &(&1 == profile.id))
            Channels.add_members(prefix, channel.id, extra_ids)
          end

          conn
          |> put_status(:created)
          |> json(%{data: channel_json(channel)})

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  @doc "POST /api/teams/:slug/channels/:channel_id/members — add members to a channel"
  def add_members(conn, %{"channel_id" => channel_id} = params) do
    prefix = conn.assigns.tenant_prefix

    member_ids = params["profile_ids"]

    unless is_list(member_ids) and member_ids != [] do
      conn
      |> put_status(:unprocessable_entity)
      |> json(%{error: "profile_ids must be a non-empty list"})
    else
      case Channels.add_members(prefix, channel_id, member_ids) do
        {:ok, count} ->
          conn
          |> put_status(:created)
          |> json(%{data: %{added: count}})

        {:error, reason} ->
          conn
          |> put_status(:unprocessable_entity)
          |> json(%{error: inspect(reason)})
      end
    end
  end

  @doc "GET /api/teams/:slug/channels/:channel_id/members — list channel members"
  def members(conn, %{"channel_id" => channel_id}) do
    prefix = conn.assigns.tenant_prefix
    members = Channels.list_members(prefix, channel_id)

    json(conn, %{data: Enum.map(members, fn m ->
      profile = m.profile
      %{
        profile_id: m.profile_id,
        role: m.role,
        joined_at: m.joined_at,
        display_name: profile && profile.display_name,
        avatar_url: profile && profile.avatar_url,
        email: profile && profile.email
      }
    end)})
  end

  @doc "DELETE /api/teams/:slug/channels/:channel_id/members/:profile_id — remove a member"
  def remove_member(conn, %{"channel_id" => channel_id, "profile_id" => profile_id}) do
    prefix = conn.assigns.tenant_prefix

    case Channels.remove_member(prefix, channel_id, profile_id) do
      {1, _} -> send_resp(conn, :no_content, "")
      {0, _} -> {:error, :not_found}
    end
  end

  defp channel_json(channel) do
    base = %{
      id: channel.id,
      name: channel.name,
      slug: channel.slug,
      icon: channel.icon,
      kind: channel.kind,
      visibility: channel.visibility,
      topic: channel.topic,
      inserted_at: channel.inserted_at
    }

    # For DMs, include member display names so client can show proper titles
    if channel.kind in ["dm", "group_dm"] do
      members = case channel.memberships do
        %Ecto.Association.NotLoaded{} -> []
        memberships when is_list(memberships) ->
          Enum.map(memberships, fn m ->
            case m.profile do
              %Ecto.Association.NotLoaded{} -> %{profile_id: m.profile_id}
              nil -> %{profile_id: m.profile_id}
              p -> %{profile_id: m.profile_id, display_name: p.display_name, avatar_url: p.avatar_url}
            end
          end)
      end
      Map.put(base, :members, members)
    else
      base
    end
  end
end
