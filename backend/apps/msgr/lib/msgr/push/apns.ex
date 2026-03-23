defmodule Messngr.Push.APNS do
  @moduledoc """
  Apple Push Notification Service (APNS) client.
  Uses HTTP/2 with JWT bearer tokens (key-based auth).
  """

  require Logger

  @apns_prod "https://api.push.apple.com"
  @apns_dev "https://api.sandbox.push.apple.com"
  @token_ttl_seconds 3500  # Refresh before 1-hour expiry

  defstruct [:key_id, :team_id, :key, :bundle_id, :environment, :token, :token_issued_at]

  def new(opts \\ []) do
    %__MODULE__{
      key_id: opts[:key_id] || Application.get_env(:msgr, __MODULE__, [])[:key_id],
      team_id: opts[:team_id] || Application.get_env(:msgr, __MODULE__, [])[:team_id],
      key: opts[:key] || load_key(),
      bundle_id: opts[:bundle_id] || Application.get_env(:msgr, __MODULE__, [])[:bundle_id] || "no.msgr.app",
      environment: opts[:environment] || Application.get_env(:msgr, __MODULE__, [])[:environment] || :production
    }
  end

  @doc """
  Send a push notification to a device token.
  """
  def push(device_token, payload, opts \\ []) do
    client = opts[:client] || new()
    client = ensure_token(client)

    url = "#{apns_url(client.environment)}/3/device/#{device_token}"

    headers = [
      {"authorization", "bearer #{client.token}"},
      {"apns-topic", client.bundle_id},
      {"apns-push-type", opts[:push_type] || "alert"},
      {"apns-priority", to_string(opts[:priority] || 10)}
    ]

    body = Jason.encode!(payload)

    case :hackney.request(:post, url, headers, body, [
      {:connect_timeout, 5000},
      {:recv_timeout, 10000}
    ]) do
      {:ok, 200, _headers, _ref} ->
        Logger.debug("APNS push sent to #{String.slice(device_token, 0..8)}...")
        :ok

      {:ok, status, _headers, ref} ->
        {:ok, resp_body} = :hackney.body(ref)
        Logger.warning("APNS push failed (#{status}): #{resp_body}")
        {:error, {:apns_error, status, resp_body}}

      {:error, reason} ->
        Logger.warning("APNS request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @doc """
  Build a standard alert payload for a chat message.
  """
  def message_payload(sender_name, content, opts \\ []) do
    %{
      "aps" => %{
        "alert" => %{
          "title" => sender_name,
          "body" => String.slice(content, 0..200)
        },
        "sound" => opts[:sound] || "default",
        "badge" => opts[:badge],
        "mutable-content" => 1,
        "thread-id" => opts[:channel_id]
      },
      "channel_id" => opts[:channel_id],
      "message_id" => opts[:message_id],
      "team_slug" => opts[:team_slug]
    }
    |> remove_nils()
  end

  # --- Private ---

  defp apns_url(:production), do: @apns_prod
  defp apns_url(:sandbox), do: @apns_dev
  defp apns_url(_), do: @apns_dev

  defp ensure_token(%{token: token, token_issued_at: issued} = client)
       when not is_nil(token) and not is_nil(issued) do
    if System.system_time(:second) - issued < @token_ttl_seconds do
      client
    else
      generate_token(client)
    end
  end

  defp ensure_token(client), do: generate_token(client)

  defp generate_token(client) do
    now = System.system_time(:second)

    header = %{"alg" => "ES256", "kid" => client.key_id}
    claims = %{"iss" => client.team_id, "iat" => now}

    header_b64 = Base.url_encode64(Jason.encode!(header), padding: false)
    claims_b64 = Base.url_encode64(Jason.encode!(claims), padding: false)

    signing_input = "#{header_b64}.#{claims_b64}"

    signature =
      :public_key.sign(signing_input, :sha256, client.key)
      |> Base.url_encode64(padding: false)

    token = "#{signing_input}.#{signature}"

    %{client | token: token, token_issued_at: now}
  end

  defp load_key do
    key_path = Application.get_env(:msgr, __MODULE__, [])[:key_path]

    cond do
      key_path && File.exists?(key_path) ->
        key_path
        |> File.read!()
        |> decode_p8_key()

      key_content = Application.get_env(:msgr, __MODULE__, [])[:key_content] ->
        decode_p8_key(key_content)

      true ->
        Logger.warning("No APNS key configured")
        nil
    end
  end

  defp decode_p8_key(pem) do
    [{:ECPrivateKey, der, :not_encrypted}] = :public_key.pem_decode(pem)
    :public_key.pem_entry_decode({:ECPrivateKey, der, :not_encrypted})
  end

  defp remove_nils(map) when is_map(map) do
    map
    |> Enum.reject(fn {_, v} -> is_nil(v) end)
    |> Enum.map(fn {k, v} -> {k, remove_nils(v)} end)
    |> Map.new()
  end

  defp remove_nils(other), do: other
end
