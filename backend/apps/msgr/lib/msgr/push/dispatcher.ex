defmodule Messngr.Push.Dispatcher do
  @moduledoc """
  Dispatches push notifications to all registered devices for channel members
  when a new message is sent.
  """

  require Logger

  alias Messngr.Push.{APNS, WebPush}

  @doc """
  Send push notifications for a new message to all channel members
  (except the sender). Runs async to not block message delivery.
  """
  def notify_new_message(team_slug, prefix, message) do
    Task.start(fn ->
      try do
        Logger.info("Push task started for team=#{team_slug}")
        sender_id = message.sender_profile_id
        channel_id = message.channel_id

        # Get sender name
        sender_name =
          if message.sender_profile do
            message.sender_profile.display_name || "Ukjent"
          else
            "Ukjent"
          end

        content = extract_text(message.content)
        if content == "", do: throw(:empty_message)

        # Get all device tokens for channel members except sender
        tokens = get_push_tokens(prefix, channel_id, sender_id)
        Logger.info("Push tokens found: #{length(tokens)} for channel=#{channel_id} sender=#{sender_id}")
        if tokens == [], do: throw(:no_tokens)

        payload = APNS.message_payload(sender_name, content,
          channel_id: channel_id,
          message_id: message.id,
          team_slug: team_slug
        )

        web_payload = WebPush.message_payload(sender_name, content,
          channel_id: channel_id,
          message_id: message.id,
          team_slug: team_slug
        )

        for {token, platform} <- tokens do
          case platform do
            "apns" -> APNS.push(token, payload)
            "web_push" -> WebPush.push(token, web_payload)
            _ -> Logger.debug("Skipping push for platform: #{platform}")
          end
        end

        Logger.debug("Push dispatched to #{length(tokens)} devices for message #{message.id}")
      catch
        :empty_message -> :ok
        :no_tokens -> Logger.debug("Push: no tokens found for channel members")
      rescue
        e -> Logger.warning("Push dispatch failed: #{inspect(e)}")
      end
    end)
  end

  defp get_push_tokens(prefix, channel_id, exclude_profile_id) do
    import Ecto.Query

    # Get all profile IDs in this channel (except sender)
    member_ids =
      from(cm in Teams.TenantModels.ChannelMembership,
        where: cm.channel_id == ^channel_id and cm.profile_id != ^exclude_profile_id,
        select: cm.profile_id
      )
      |> Teams.Repo.all(prefix: prefix)

    if member_ids == [] do
      []
    else
      # Get account IDs for these profiles
      account_ids =
        from(p in Teams.TenantModels.Profile,
          where: p.id in ^member_ids,
          select: p.account_id
        )
        |> Teams.Repo.all(prefix: prefix)

      if account_ids == [] do
        []
      else
        # Get push tokens using the proper schema
        from(t in Messngr.Push.DeviceToken,
          where: t.account_id in ^account_ids and t.enabled == true,
          select: {t.token, t.platform}
        )
        |> Messngr.Repo.all()
      end
    end
  rescue
    e ->
      Logger.warning("get_push_tokens failed: #{inspect(e)}")
      []
  end

  defp extract_text(%{"text" => text}) when is_binary(text), do: text
  defp extract_text(content) when is_binary(content), do: content
  defp extract_text(content) when is_map(content), do: Map.get(content, "text", "")
  defp extract_text(_), do: ""
end
