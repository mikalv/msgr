defmodule MessngrWeb.WebhookController do
  @moduledoc """
  Handles incoming webhook messages from external services.

  POST /api/hooks/:token — no auth required, token IS the auth.

  Accepts Slack-compatible format:
    {"text": "Hello", "username": "CI Bot", "icon_emoji": ":rocket:"}

  And simple format:
    {"content": "Hello", "name": "CI Bot"}
  """

  use MessngrWeb, :controller
  require Logger

  alias Messngr.Teams.WebhookEndpoint
  alias Teams.{Messages, Channels, TeamManagement}

  @doc "POST /api/hooks/:token — receive a webhook message"
  def receive(conn, %{"token" => token} = params) do
    case WebhookEndpoint.get_by_token(token) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Invalid webhook token"})

      endpoint ->
        team = endpoint.team
        prefix = team.schema_name

        # Render message via template engine (supports Liquid templates, presets, and fallback)
        {text, bot_name} = case Messngr.Webhooks.TemplateEngine.render(params, endpoint.template, endpoint.template_preset) do
          {:ok, rendered} ->
            name = params["username"] || params["name"] || endpoint.name
            {rendered, name}
          _ ->
            extract_message(params, endpoint)
        end

        if text == nil or text == "" do
          conn
          |> put_status(:bad_request)
          |> json(%{error: "No message content. Send {\"text\": \"...\"} or {\"content\": \"...\"}"})
        else
          # Find or create a bot profile for this webhook
          bot_profile = ensure_bot_profile(prefix, endpoint, bot_name)

          # Create the message
          attrs = %{
            channel_id: endpoint.channel_id,
            sender_profile_id: bot_profile.id,
            content: %{"text" => text}
          }

          case Messages.create_message(prefix, attrs) do
            {:ok, message} ->
              message = Messages.get_message(prefix, message.id)

              # Broadcast via Phoenix PubSub so connected clients see it
              broadcast_message(team, prefix, message)

              # Increment webhook usage counter
              WebhookEndpoint.increment_count(endpoint)

              Logger.info("Webhook message received: team=#{team.slug} channel=#{endpoint.channel_id} webhook=#{endpoint.name}")

              conn
              |> put_status(:ok)
              |> json(%{ok: true, message_id: message.id})

            {:error, reason} ->
              Logger.warning("Webhook message creation failed: #{inspect(reason)}")
              conn
              |> put_status(:unprocessable_entity)
              |> json(%{error: "Failed to create message"})
          end
        end
    end
  end

  # --- Message extraction ---

  defp extract_message(params, endpoint) do
    # Slack format: text, username, icon_emoji
    # Simple format: content, name
    text = params["text"] || params["content"] || extract_blocks_text(params["blocks"])
    bot_name = params["username"] || params["name"] || endpoint.name

    {text, bot_name}
  end

  defp extract_blocks_text(nil), do: nil
  defp extract_blocks_text(blocks) when is_list(blocks) do
    # Extract text from Slack blocks (simplified — handles section blocks)
    blocks
    |> Enum.map(fn
      %{"type" => "section", "text" => %{"text" => text}} -> text
      %{"text" => %{"text" => text}} -> text
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n")
    |> case do
      "" -> nil
      text -> text
    end
  end
  defp extract_blocks_text(_), do: nil

  # --- Bot profile ---

  defp ensure_bot_profile(prefix, endpoint, bot_name) do
    # Look for existing bot profile by webhook name
    import Ecto.Query

    case Teams.Repo.get_by(Teams.TenantModels.Profile,
           [display_name: bot_name, role: "bot"],
           prefix: prefix) do
      nil ->
        # Create bot profile (no account_id needed for bots)
        {:ok, profile} = Teams.TenantModels.Profile.create(prefix, %{
          display_name: bot_name,
          role: "bot",
          avatar_url: endpoint.avatar_url
        })

        # Auto-join the channel
        Teams.TenantModels.ChannelMembership.join(prefix, %{
          channel_id: endpoint.channel_id,
          profile_id: profile.id,
          role: "member"
        })

        profile

      profile ->
        profile
    end
  end

  # --- Broadcast ---

  defp broadcast_message(team, prefix, message) do
    # Broadcast to the channel topic so connected clients see the message
    payload = %{
      id: message.id,
      channel_id: message.channel_id,
      sender_profile_id: message.sender_profile_id,
      content: message.content,
      media_refs: message.media_refs || [],
      inserted_at: message.inserted_at,
      sender_profile: if(message.sender_profile, do: %{
        id: message.sender_profile.id,
        display_name: message.sender_profile.display_name,
        avatar_url: message.sender_profile.avatar_url,
        role: message.sender_profile.role
      })
    }

    MessngrWeb.Endpoint.broadcast!(
      "channel:#{message.channel_id}",
      "new:message",
      payload
    )

    # Also broadcast to team topic for unread counts
    MessngrWeb.Endpoint.broadcast!(
      "team:#{team.slug}",
      "channel:new_message",
      %{
        channel_id: message.channel_id,
        sender_profile_id: message.sender_profile_id
      }
    )
  end
end
