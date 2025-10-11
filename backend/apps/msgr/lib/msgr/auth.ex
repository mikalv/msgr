defmodule Messngr.Auth do
  @moduledoc """
  Handles passwordless OTP and federated sign-in flows for Messngr clients.
  """

  alias Messngr.Accounts
  alias Messngr.Accounts.Identity
  alias Messngr.Auth.Challenge
  alias Messngr.Repo

  @challenge_ttl_minutes 10

  @type channel :: :email | :phone

  @spec start_challenge(map()) :: {:ok, Challenge.t(), String.t()} | {:error, term()}
  def start_challenge(attrs) do
    with {:ok, channel} <- normalize_channel(Map.get(attrs, "channel")),
         {:ok, target} <- normalize_target(channel, Map.get(attrs, "identifier")),
         {:ok, {challenge, code}} <- persist_challenge(channel, target, attrs) do
      {:ok, challenge, code}
    end
  end

  @spec verify_challenge(binary(), String.t(), map()) ::
          {:ok, %{account: Accounts.Account.t(), identity: Identity.t()}} | {:error, term()}
  def verify_challenge(id, code, attrs \\ %{}) do
    Repo.transaction(fn ->
      challenge = Repo.get!(Challenge, id)

      with :ok <- ensure_not_consumed(challenge),
           :ok <- ensure_not_expired(challenge),
           :ok <- compare_code(challenge, code),
           {:ok, identity} <- upsert_identity_from_challenge(challenge, attrs),
           {:ok, _} <- mark_challenge_consumed(challenge),
           {:ok, identity} <- Accounts.verify_identity(identity, %{last_challenged_at: challenge.inserted_at}),
           {:ok, %{identity: identity}} <- Accounts.attach_device_for_identity(identity, device_attrs_from(challenge, attrs)) do
        %{account: identity.account, identity: identity}
      else
        {:error, reason} -> Repo.rollback(reason)
        error -> Repo.rollback(error)
      end
    end)
  end

  @spec complete_oidc(map()) :: {:ok, %{account: Accounts.Account.t(), identity: Identity.t()}} | {:error, term()}
  def complete_oidc(attrs) do
    with {:ok, provider} <- require_value(attrs, "provider"),
         {:ok, subject} <- require_value(attrs, "subject"),
         {:ok, identity} <- Accounts.ensure_identity(%{
           kind: :oidc,
           provider: provider,
           subject: subject,
           email: Map.get(attrs, "email"),
           display_name: Map.get(attrs, "name")
         }),
         {:ok, identity} <- Accounts.verify_identity(identity, %{}),
         {:ok, %{identity: identity}} <- Accounts.attach_device_for_identity(identity, device_attrs_from(nil, attrs)) do
      {:ok, %{account: identity.account, identity: identity}}
    end
  end

  defp device_attrs_from(%Challenge{} = challenge, attrs) do
    %{
      device_public_key: challenge.issued_for,
      attesters: Map.get(attrs, "attesters"),
      last_handshake_at: Map.get(attrs, "last_handshake_at"),
      profile_id: Map.get(attrs, "profile_id")
    }
  end

  defp device_attrs_from(nil, attrs) do
    %{
      device_public_key:
        Map.get(attrs, "device_public_key") ||
          Map.get(attrs, "device_id"),
      attesters: Map.get(attrs, "attesters"),
      last_handshake_at: Map.get(attrs, "last_handshake_at"),
      profile_id: Map.get(attrs, "profile_id")
    }
  end

  defp persist_challenge(channel, target, attrs) do
    Repo.transaction(fn ->
      identity = Accounts.get_identity_by_channel(channel, target)
      code = generate_code()

      params = %{
        "channel" => channel,
        "target" => target,
        "code_hash" => hash_code(code),
        "expires_at" => DateTime.utc_now() |> DateTime.add(@challenge_ttl_minutes * 60, :second),
        "identity_id" => identity && identity.id,
        "issued_for" => Map.get(attrs, "device_id")
      }

      with {:ok, challenge} <-
             %Challenge{}
             |> Challenge.changeset(params)
             |> Repo.insert() do
        if identity do
          Accounts.touch_identity(identity, %{last_challenged_at: challenge.inserted_at})
        end

        {challenge, code}
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp upsert_identity_from_challenge(challenge, attrs) do
    Accounts.ensure_identity(%{
      kind: challenge.channel,
      value: challenge.target,
      display_name: Map.get(attrs, "display_name"),
      email: channel_email(challenge),
      phone_number: channel_phone(challenge)
    })
  end

  defp channel_email(%Challenge{channel: :email, target: target}), do: target
  defp channel_email(_), do: nil

  defp channel_phone(%Challenge{channel: :phone, target: target}), do: target
  defp channel_phone(_), do: nil

  defp ensure_not_consumed(%Challenge{consumed_at: nil}), do: :ok
  defp ensure_not_consumed(_), do: {:error, :already_consumed}

  defp ensure_not_expired(%Challenge{expires_at: expires_at}) do
    case DateTime.compare(expires_at, DateTime.utc_now()) do
      :lt -> {:error, :expired}
      _ -> :ok
    end
  end

  defp compare_code(%Challenge{code_hash: code_hash}, code) do
    hashed = hash_code(code)

    if Plug.Crypto.secure_compare(code_hash, hashed) do
      :ok
    else
      {:error, :invalid_code}
    end
  end

  defp mark_challenge_consumed(challenge) do
    challenge
    |> Challenge.changeset(%{"consumed_at" => DateTime.utc_now()})
    |> Repo.update()
  end

  defp normalize_channel(value) do
    case value do
      "email" -> {:ok, :email}
      :email -> {:ok, :email}
      "phone" -> {:ok, :phone}
      :phone -> {:ok, :phone}
      _ -> {:error, :unsupported_channel}
    end
  end

  defp normalize_target(:email, nil), do: {:error, :missing_identifier}
  defp normalize_target(:email, identifier) do
    identifier = identifier |> String.trim() |> String.downcase()

    if Regex.match?(~r/@/, identifier) do
      {:ok, identifier}
    else
      {:error, :invalid_email}
    end
  end

  defp normalize_target(:phone, nil), do: {:error, :missing_identifier}
  defp normalize_target(:phone, identifier) do
    normalized = identifier |> String.replace(~r/\s+/, "")

    if String.starts_with?(normalized, "+") and String.length(normalized) >= 8 do
      {:ok, normalized}
    else
      {:error, :invalid_phone}
    end
  end

  defp require_value(map, key) do
    case Map.get(map, key) do
      nil -> {:error, {:missing, key}}
      value -> {:ok, value}
    end
  end

  defp generate_code do
    :rand.uniform(1_000_000) |> Integer.to_string() |> String.pad_leading(6, "0")
  end

  defp hash_code(code), do: :crypto.hash(:sha256, code) |> Base.encode64()
end
