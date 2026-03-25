defmodule Messngr.Push.WebPush do
  @moduledoc """
  Web Push notification sender using the web_push_elixir library.

  Subscriptions are stored as JSON in the `token` column of `device_push_tokens`
  with platform="web_push".
  """

  require Logger

  @doc "Send a web push notification to a subscription (JSON string or map)."
  def push(subscription_json, payload) when is_binary(subscription_json) do
    case Jason.decode(subscription_json) do
      {:ok, subscription} -> push_decoded(subscription, payload)
      {:error, _} -> {:error, :invalid_subscription}
    end
  end

  def push(subscription, payload) when is_map(subscription) do
    push_decoded(subscription, payload)
  end

  defp push_decoded(subscription, payload) do
    json_payload = if is_binary(payload), do: payload, else: Jason.encode!(payload)

    vapid = Application.get_env(:msgr, __MODULE__, [])
    public_key = vapid[:public_key]
    private_key = vapid[:private_key]
    subject = vapid[:subject] || "mailto:admin@msgr.no"

    if is_nil(public_key) or is_nil(private_key) do
      Logger.warning("[WebPush] VAPID keys not configured, skipping")
      {:error, :no_vapid_keys}
    else
      try do
        result = WebPushElixir.send_notification(
          subscription,
          json_payload,
          %{
            vapid_public_key: public_key,
            vapid_private_key: private_key,
            vapid_subject: subject
          }
        )

        case result do
          {:ok, %{status: status}} when status in 200..299 ->
            Logger.debug("[WebPush] Sent successfully (#{status})")
            :ok

          {:ok, %{status: status}} when status in [404, 410] ->
            Logger.info("[WebPush] Subscription expired (#{status})")
            {:error, :subscription_expired}

          {:ok, %{status: status, body: body}} ->
            Logger.warning("[WebPush] Failed: #{status} — #{inspect(body)}")
            {:error, {:http_error, status}}

          {:error, reason} ->
            Logger.warning("[WebPush] Request failed: #{inspect(reason)}")
            {:error, reason}

          other ->
            Logger.warning("[WebPush] Unexpected result: #{inspect(other)}")
            {:error, :unexpected}
        end
      rescue
        e ->
          Logger.warning("[WebPush] Exception: #{inspect(e)}")
          {:error, e}
      end
    end
  end

  @doc "Build a notification payload for a new message."
  def message_payload(sender_name, content, opts \\ []) do
    %{
      title: sender_name,
      body: String.slice(content, 0, 200),
      icon: "/icons/Icon-192.png",
      badge: "/icons/Icon-192.png",
      tag: "msg-#{opts[:channel_id]}",
      data: %{
        channel_id: opts[:channel_id],
        message_id: opts[:message_id],
        team_slug: opts[:team_slug],
        type: "new_message"
      }
    }
  end

  @doc "Generate a new VAPID key pair. Returns {public_key_b64, private_key_b64}."
  def generate_vapid_keys do
    {public, private} = :crypto.generate_key(:ecdh, :prime256v1)
    {Base.url_encode64(public, padding: false), Base.url_encode64(private, padding: false)}
  end
end
