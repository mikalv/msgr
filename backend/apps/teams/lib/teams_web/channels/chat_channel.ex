defmodule TeamsWeb.ChatChannel do
  @moduledoc """
  Per-channel realtime messaging: messages, threads, reactions,
  typing indicators, and read cursors.

  Topic: "channel:{channel_id}"

  Socket assigns expected from UserSocket:
    - :uid (account_id)
    - :tenant (schema prefix)
    - :profile_id
  """

  use TeamsWeb, :channel
  require Logger

  alias Teams.{Messages, Channels, Reactions, TeamManagement}
  alias Teams.TenantModels.{Channel, ChannelMembership, ReadCursor}

  @impl true
  def join("channel:" <> channel_id, payload, socket) do
    profile_id = socket.assigns[:profile_id]

    # Resolve tenant prefix: prefer socket assign (from JWT), fall back to
    # team_slug in join payload (header-based auth from Flutter).
    prefix =
      case socket.assigns[:tenant] do
        nil ->
          team_slug = Map.get(payload || %{}, "team_slug")
          if team_slug do
            case TeamManagement.get_team_by_slug(team_slug) do
              nil -> nil
              team -> team.schema_name
            end
          else
            nil
          end
        t -> t
      end

    if is_nil(prefix) do
      {:error, %{reason: "tenant_not_resolved"}}
    else
      case Channels.get_channel(prefix, channel_id) do
        nil ->
          {:error, %{reason: "channel_not_found"}}

        channel ->
          # Resolve the tenant profile for this account
          account_id = socket.assigns[:uid] || socket.assigns[:account_id]
          tenant_profile = if account_id do
            TeamManagement.get_profile_for_account(prefix, account_id)
          end
          tenant_profile_id = if tenant_profile, do: tenant_profile.id, else: profile_id

          if has_access?(prefix, channel, tenant_profile_id) do
            # Resolve team_slug for push notifications
            team_slug =
              Map.get(payload || %{}, "team_slug") ||
              socket.assigns[:team_slug] ||
              resolve_slug_from_prefix(prefix)

            socket =
              socket
              |> assign(:channel_id, channel_id)
              |> assign(:prefix, prefix)
              |> assign(:profile_id, tenant_profile_id)
              |> assign(:team_slug, team_slug)

            send(self(), :after_join)
            {:ok, socket}
          else
            {:error, %{reason: "unauthorized"}}
          end
      end
    end
  end

  @impl true
  def handle_info(:after_join, socket) do
    # Push the current read cursor for this profile so the client
    # knows where they left off.
    prefix = socket.assigns[:prefix]
    channel_id = socket.assigns[:channel_id]
    profile_id = socket.assigns[:profile_id]

    case ReadCursor.get(prefix, channel_id, profile_id) do
      nil -> :ok
      cursor ->
        push(socket, "read_cursor:updated", %{
          channel_id: channel_id,
          profile_id: profile_id,
          last_read_message_id: cursor.last_read_message_id
        })
    end

    {:noreply, socket}
  end

  # ── Incoming events ──────────────────────────────────────────

  @impl true
  # Accept both "message:create" (Flutter client) and "new:message" (legacy)
  def handle_in("message:create", payload, socket), do: handle_in("new:message", payload, socket)

  def handle_in("new:message", %{"content" => content} = payload, socket) do
    prefix = socket.assigns[:prefix]
    channel_id = socket.assigns[:channel_id]
    profile_id = socket.assigns[:profile_id]

    attrs = %{
      channel_id: channel_id,
      sender_profile_id: profile_id,
      content: content,
      media_refs: Map.get(payload, "media_refs", [])
    }

    case Messages.create_message(prefix, attrs) do
      {:ok, message} ->
        message = Messages.get_message(prefix, message.id)

        broadcast!(socket, "new:message", serialize_message(message))

        # Dispatch push notifications to offline members
        team_slug = socket.assigns[:team_slug]
        Logger.info("Push dispatch: team_slug=#{inspect(team_slug)} prefix=#{inspect(prefix)}")
        if team_slug do
          Messngr.Push.Dispatcher.notify_new_message(team_slug, prefix, message)
        else
          # Fallback: resolve slug from prefix
          resolved = resolve_slug_from_prefix(prefix)
          Logger.info("Push dispatch fallback: resolved=#{inspect(resolved)}")
          if resolved, do: Messngr.Push.Dispatcher.notify_new_message(resolved, prefix, message)
        end

        {:reply, {:ok, %{id: message.id}}, socket}

      {:error, changeset} ->
        Logger.warning("Failed to create message: #{inspect(changeset)}")
        {:reply, {:error, %{reason: "invalid_message"}}, socket}
    end
  end

  def handle_in("new:thread_reply", %{"thread_parent_id" => parent_id, "content" => content} = payload, socket) do
    prefix = socket.assigns[:prefix]
    channel_id = socket.assigns[:channel_id]
    profile_id = socket.assigns[:profile_id]

    attrs = %{
      channel_id: channel_id,
      sender_profile_id: profile_id,
      thread_parent_id: parent_id,
      content: content,
      media_refs: Map.get(payload, "media_refs", [])
    }

    case Messages.create_message(prefix, attrs) do
      {:ok, message} ->
        message = Messages.get_message(prefix, message.id)

        broadcast!(socket, "new:thread_reply", %{
          thread_parent_id: parent_id,
          message: serialize_message(message)
        })

        # Dispatch push notifications for thread replies too
        team_slug = socket.assigns[:team_slug]
        if team_slug do
          Messngr.Push.Dispatcher.notify_new_message(team_slug, prefix, message)
        end

        {:reply, {:ok, %{id: message.id}}, socket}

      {:error, changeset} ->
        Logger.warning("Failed to create thread reply: #{inspect(changeset)}")
        {:reply, {:error, %{reason: "invalid_message"}}, socket}
    end
  end

  def handle_in("toggle:reaction", %{"message_id" => message_id, "emoji" => emoji}, socket) do
    prefix = socket.assigns[:prefix]
    profile_id = socket.assigns[:profile_id]

    case Reactions.toggle_reaction(prefix, message_id, profile_id, emoji) do
      {:ok, _result} ->
        reactions = Reactions.list_reactions(prefix, message_id)

        broadcast!(socket, "reaction:updated", %{
          message_id: message_id,
          reactions: serialize_reactions(reactions)
        })

        {:reply, :ok, socket}

      {:error, reason} ->
        Logger.warning("Failed to toggle reaction: #{inspect(reason)}")
        {:reply, {:error, %{reason: "reaction_failed"}}, socket}
    end
  end

  def handle_in("typing:start", _payload, socket) do
    profile_id = socket.assigns[:profile_id]

    broadcast_from!(socket, "typing:update", %{
      profile_id: profile_id,
      is_typing: true
    })

    {:noreply, socket}
  end

  def handle_in("typing:stop", _payload, socket) do
    profile_id = socket.assigns[:profile_id]

    broadcast_from!(socket, "typing:update", %{
      profile_id: profile_id,
      is_typing: false
    })

    {:noreply, socket}
  end

  def handle_in("update:read_cursor", %{"last_read_message_id" => message_id}, socket) do
    prefix = socket.assigns[:prefix]
    channel_id = socket.assigns[:channel_id]
    profile_id = socket.assigns[:profile_id]

    case ReadCursor.upsert(prefix, %{
           channel_id: channel_id,
           profile_id: profile_id,
           last_read_message_id: message_id
         }) do
      {:ok, _cursor} ->
        # Broadcast to the sender's other devices via the user-specific topic
        broadcast!(socket, "read_cursor:updated", %{
          channel_id: channel_id,
          profile_id: profile_id,
          last_read_message_id: message_id
        })

        {:reply, :ok, socket}

      {:error, reason} ->
        Logger.warning("Failed to update read cursor: #{inspect(reason)}")
        {:reply, {:error, %{reason: "cursor_update_failed"}}, socket}
    end
  end

  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  # ── Private ──────────────────────────────────────────────────

  defp has_access?(prefix, channel, profile_id) do
    # Public channels are accessible to all team members.
    # Private channels / DMs require membership.
    case channel.visibility do
      "public" ->
        true

      "private" ->
        members = ChannelMembership.members_of(prefix, channel.id)
        Enum.any?(members, fn m -> m.profile_id == profile_id end)
    end
  end

  defp serialize_message(nil), do: nil

  defp serialize_message(message) do
    %{
      id: message.id,
      channel_id: message.channel_id,
      sender_profile_id: message.sender_profile_id,
      thread_parent_id: message.thread_parent_id,
      content: message.content,
      media_refs: message.media_refs,
      edited_at: message.edited_at,
      inserted_at: message.inserted_at,
      sender_profile: serialize_profile(message.sender_profile),
      reactions: serialize_reactions(message.reactions)
    }
  end

  defp serialize_profile(%Ecto.Association.NotLoaded{}), do: nil

  defp serialize_profile(nil), do: nil

  defp serialize_profile(profile) do
    %{
      id: profile.id,
      display_name: profile.display_name,
      avatar_url: profile.avatar_url,
      role: profile.role
    }
  end

  defp resolve_slug_from_prefix(prefix) when is_binary(prefix) do
    case Teams.Repo.get_by(Teams.Schemas.Team, schema_name: prefix) do
      nil -> nil
      team -> team.slug
    end
  end

  defp resolve_slug_from_prefix(_), do: nil

  defp serialize_reactions(%Ecto.Association.NotLoaded{}), do: []

  defp serialize_reactions(reactions) when is_list(reactions) do
    Enum.map(reactions, fn r ->
      %{
        message_id: r.message_id,
        profile_id: r.profile_id,
        emoji: r.emoji
      }
    end)
  end
end
