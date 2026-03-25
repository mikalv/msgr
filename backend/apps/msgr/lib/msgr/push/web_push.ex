defmodule Messngr.Push.WebPush do
  @moduledoc """
  Web Push notification sender using VAPID authentication and RFC 8291 encryption.

  Implements the Web Push protocol without external dependencies — uses
  Erlang :crypto for ECDH/AES and JOSE for VAPID JWT signing.

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

    if is_nil(public_key) or is_nil(private_key) do
      Logger.warning("[WebPush] VAPID keys not configured, skipping")
      {:error, :no_vapid_keys}
    else
      endpoint = subscription["endpoint"]
      p256dh = subscription["keys"]["p256dh"]
      auth = subscription["keys"]["auth"]

      if is_nil(endpoint) or is_nil(p256dh) or is_nil(auth) do
        {:error, :invalid_subscription}
      else
        send_push(endpoint, p256dh, auth, json_payload, public_key, private_key, vapid[:subject] || "mailto:admin@msgr.no")
      end
    end
  end

  defp send_push(endpoint, p256dh_b64, auth_b64, plaintext, vapid_public_b64, vapid_private_b64, subject) do
    try do
      # Decode subscription keys
      ua_public = url_base64_decode(p256dh_b64)
      auth_secret = url_base64_decode(auth_b64)

      # Generate ephemeral ECDH key pair
      {local_public, local_private} = :crypto.generate_key(:ecdh, :prime256v1)

      # ECDH shared secret
      shared_secret = :crypto.compute_key(:ecdh, ua_public, local_private, :prime256v1)

      # RFC 8291 key derivation
      # PRK = HKDF-Extract(auth_secret, shared_secret)
      prk_key = hkdf_extract(auth_secret, shared_secret)

      # Info for key derivation
      key_info = create_info("aesgcm", ua_public, local_public)
      nonce_info = create_info("nonce", ua_public, local_public)

      # Derive content encryption key and nonce
      cek = hkdf_expand(prk_key, key_info, 16)
      nonce = hkdf_expand(prk_key, nonce_info, 12)

      # Pad plaintext (RFC 8291 §4: 2-byte padding length prefix)
      padding_length = 0
      padded = <<padding_length::16>> <> plaintext

      # AES-128-GCM encrypt
      {ciphertext, tag} = :crypto.crypto_one_time_aead(:aes_128_gcm, cek, nonce, padded, "", true)
      encrypted_body = ciphertext <> tag

      # VAPID JWT
      uri = URI.parse(endpoint)
      audience = "#{uri.scheme}://#{uri.host}"
      vapid_headers = build_vapid_headers(vapid_public_b64, vapid_private_b64, audience, subject)

      # HTTP request
      headers = [
        {"Content-Type", "application/octet-stream"},
        {"Content-Encoding", "aesgcm"},
        {"Content-Length", Integer.to_string(byte_size(encrypted_body))},
        {"Crypto-Key", "dh=#{url_base64_encode(local_public)};#{vapid_headers.crypto_key}"},
        {"Encryption", "salt=#{url_base64_encode(:crypto.strong_rand_bytes(16))}"},
        {"Authorization", vapid_headers.authorization},
        {"TTL", "86400"}
      ]

      case Finch.build(:post, endpoint, headers, encrypted_body)
           |> Finch.request(Messngr.Finch) do
        {:ok, %{status: status}} when status in 200..299 ->
          Logger.debug("[WebPush] Sent successfully (#{status})")
          :ok

        {:ok, %{status: status}} when status in [404, 410] ->
          Logger.info("[WebPush] Subscription expired (#{status})")
          {:error, :subscription_expired}

        {:ok, %{status: status, body: body}} ->
          Logger.warning("[WebPush] Failed: #{status} — #{body}")
          {:error, {:http_error, status}}

        {:error, reason} ->
          Logger.warning("[WebPush] Request failed: #{inspect(reason)}")
          {:error, reason}
      end
    rescue
      e ->
        Logger.warning("[WebPush] Exception: #{inspect(e)}")
        {:error, e}
    end
  end

  # --- VAPID ---

  defp build_vapid_headers(public_b64, private_b64, audience, subject) do
    now = System.system_time(:second)

    claims = %{
      "aud" => audience,
      "exp" => now + 12 * 3600,
      "sub" => subject
    }

    private_bytes = url_base64_decode(private_b64)

    # Build EC JWK from raw private key bytes (P-256 / prime256v1)
    jwk = JOSE.JWK.from_map(%{
      "kty" => "EC",
      "crv" => "P-256",
      "d" => Base.url_encode64(private_bytes, padding: false),
      "x" => Base.url_encode64(binary_part(url_base64_decode(public_b64), 1, 32), padding: false),
      "y" => Base.url_encode64(binary_part(url_base64_decode(public_b64), 33, 32), padding: false)
    })

    {_, compact} = JOSE.JWT.sign(jwk, %{"alg" => "ES256"}, claims) |> JOSE.JWS.compact()

    %{
      authorization: "vapid t=#{compact}, k=#{public_b64}",
      crypto_key: "p256ecdsa=#{public_b64}"
    }
  end

  # --- HKDF ---

  defp hkdf_extract(salt, ikm) do
    :crypto.mac(:hmac, :sha256, salt, ikm)
  end

  defp hkdf_expand(prk, info, length) do
    t1 = :crypto.mac(:hmac, :sha256, prk, info <> <<1>>)
    binary_part(t1, 0, length)
  end

  defp create_info(type, ua_public, local_public) do
    "Content-Encoding: " <> type <> <<0>> <>
      "P-256" <> <<0>> <>
      <<byte_size(ua_public)::16>> <> ua_public <>
      <<byte_size(local_public)::16>> <> local_public
  end

  # --- Base64 URL ---

  defp url_base64_decode(str) do
    padded = str <> String.duplicate("=", rem(4 - rem(String.length(str), 4), 4))
    Base.url_decode64!(padded)
  end

  defp url_base64_encode(bytes) do
    Base.url_encode64(bytes, padding: false)
  end

  # --- VAPID Key Generation ---

  @doc "Generate a new VAPID key pair. Returns {public_key_b64, private_key_b64}."
  def generate_vapid_keys do
    {public, private} = :crypto.generate_key(:ecdh, :prime256v1)
    {url_base64_encode(public), url_base64_encode(private)}
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
end
