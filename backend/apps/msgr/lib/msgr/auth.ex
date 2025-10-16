defmodule Messngr.Auth do
  @moduledoc """
  Handles passwordless OTP and federated sign-in flows for Messngr clients.
  """

  alias Messngr.Accounts
  alias Messngr.Accounts.Identity
  alias Messngr.Auth.Challenge
  alias Messngr.Auth.Notifier
  alias Messngr.FeatureFlags
  alias Messngr.Noise.Handshake
  alias Messngr.Noise.SessionStore
  alias Messngr.Noise.SessionStore.Actor, as: NoiseActor
  alias Messngr.Transport.Noise.Session
  alias Messngr.Repo
  alias Messngr.RateLimiter

  alias Ecto.NoResultsError

  @challenge_ttl_minutes 10

  @type channel :: :email | :phone

  @spec start_challenge(map()) :: {:ok, Challenge.t(), String.t()} | {:error, term()}
  def start_challenge(attrs) do
    with {:ok, channel} <- normalize_channel(Map.get(attrs, "channel")),
         {:ok, target} <- normalize_target(channel, Map.get(attrs, "identifier")),
         :ok <- throttle_challenge_requests(channel, target),
         {:ok, {challenge, code}} <- persist_challenge(channel, target, attrs),
         :ok <- deliver_challenge(challenge, code) do
      {:ok, challenge, code}
    end
  end

  @spec verify_challenge(binary(), String.t(), map()) :: {:ok, map()} | {:error, term()}
  def verify_challenge(id, code, attrs \\ %{}) do
    with {:ok, handshake} <- maybe_resolve_handshake(attrs) do
      Repo.transaction(fn ->
        challenge = Repo.get!(Challenge, id)

        with :ok <- ensure_not_consumed(challenge),
             :ok <- ensure_not_expired(challenge),
             :ok <- compare_code(challenge, code),
             :ok <- ensure_noise_device_matches(challenge, handshake),
             {:ok, identity} <- upsert_identity_from_challenge(challenge, attrs),
             {:ok, _} <- mark_challenge_consumed(challenge),
             {:ok, identity} <-
               Accounts.verify_identity(identity, %{last_challenged_at: challenge.inserted_at}),
             {:ok, %{identity: identity, device: device}} <-
               Accounts.attach_device_for_identity(identity, device_attrs_from(challenge, attrs)),
             {:ok, noise_session} <- maybe_finalize_handshake(handshake, identity, device) do
          %{account: identity.account, identity: identity}
          |> maybe_put_noise_session(noise_session)
        else
          {:error, reason} -> Repo.rollback(reason)
          error -> Repo.rollback(error)
        end
      end)
    end
  end

  @spec complete_oidc(map()) ::
          {:ok, %{account: Accounts.Account.t(), identity: Identity.t()}} | {:error, term()}
  def complete_oidc(attrs) do
    with {:ok, provider} <- require_value(attrs, "provider"),
         {:ok, subject} <- require_value(attrs, "subject"),
         {:ok, identity} <-
           Accounts.ensure_identity(%{
             kind: :oidc,
             provider: provider,
             subject: subject,
             email: Map.get(attrs, "email"),
             display_name: Map.get(attrs, "name")
           }),
         {:ok, identity} <- Accounts.verify_identity(identity, %{}),
         {:ok, %{identity: identity}} <-
           Accounts.attach_device_for_identity(identity, device_attrs_from(nil, attrs)) do
      {:ok, %{account: identity.account, identity: identity}}
    end
  end

  defp maybe_resolve_handshake(attrs) do
    if FeatureFlags.require_noise_handshake?() do
      started_at = System.monotonic_time()

      with {:ok, session_id} <- require_value(attrs, "noise_session_id"),
           {:ok, signature_raw} <- require_value(attrs, "noise_signature"),
           {:ok, signature} <- decode_noise_signature(signature_raw),
           {:ok, session} <- fetch_noise_session(session_id),
           :ok <- verify_noise_signature(session, signature) do
        metadata = %{session_id: Session.id(session)}
        emit_handshake_event(:success, started_at, metadata)
        {:ok, %{session: session}}
      else
        {:error, reason} ->
          metadata = handshake_failure_metadata(binding(), reason)
          emit_handshake_event(:failure, started_at, metadata)
          {:error, {:noise_handshake, reason}}
      end
    else
      {:ok, nil}
    end
  end

  defp fetch_noise_session(session_id) do
    case Handshake.fetch(session_id) do
      {:ok, session} -> {:ok, session}
      :error -> {:error, :noise_session_not_found}
    end
  end

  defp decode_noise_signature(value) do
    case Handshake.decode_signature(value) do
      {:ok, signature} -> {:ok, signature}
      :error -> {:error, :invalid_noise_signature}
    end
  end

  defp verify_noise_signature(session, signature) do
    case Handshake.verify_signature(session, signature) do
      :ok -> :ok
      {:error, _} -> {:error, :invalid_noise_signature}
    end
  end

  defp maybe_finalize_handshake(nil, _identity, _device), do: {:ok, nil}

  defp maybe_finalize_handshake(%{session: session}, identity, device) do
    with {:ok, actor} <- handshake_actor(identity, device),
         {:ok, %{session: session, token: token}} <- Handshake.finalize(session, actor) do
      {:ok, %{id: Session.id(session), token: token}}
    else
      {:error, reason} -> {:error, {:noise_handshake, reason}}
    end
  end

  @spec switch_profile(String.t(), Ecto.UUID.t(), Ecto.UUID.t(), keyword()) ::
          {:ok,
           %{
             session: Session.t(),
             actor: NoiseActor.t(),
             profile: Accounts.Profile.t(),
             device: Accounts.Device.t() | nil,
             token: String.t()
           }}
          | {:error, term()}
  def switch_profile(encoded_token, account_id, profile_id, opts \\ []) do
    with {:ok, raw_token} <- SessionStore.decode_token(encoded_token),
         {:ok, session, %NoiseActor{} = actor} <- SessionStore.fetch(raw_token, opts),
         :ok <- ensure_actor_account(actor, account_id),
         {:ok, profile} <- Accounts.ensure_profile_for_account(account_id, profile_id),
         {:ok, device} <- maybe_reassign_device(actor, profile),
         {:ok, session, %NoiseActor{} = updated_actor} <-
           SessionStore.switch_profile(raw_token, profile.id, opts) do
      token = SessionStore.encode_token(Session.token(session))

      {:ok,
       %{
         session: session,
         actor: updated_actor,
         profile: profile,
         device: device,
         token: token
       }}
    else
      :error -> {:error, :invalid_token}
      {:error, reason} -> {:error, reason}
    end
  end

  defp handshake_actor(identity, device) do
    profile_id =
      cond do
        is_binary(device.profile_id) and byte_size(String.trim(device.profile_id)) > 0 ->
          String.trim(device.profile_id)

        identity.account && is_list(identity.account.profiles) ->
          identity.account.profiles
          |> List.first()
          |> case do
            nil -> nil
            profile -> profile.id
          end

        true ->
          nil
      end

    cond do
      not is_binary(identity.account_id) ->
        {:error, {:noise_handshake, :noise_account_missing}}

      not is_binary(device.id) ->
        {:error, {:noise_handshake, :noise_device_missing}}

      not is_binary(device.device_public_key) ->
        {:error, {:noise_handshake, :noise_device_missing}}

      not is_binary(profile_id) ->
        {:error, {:noise_handshake, :noise_profile_missing}}

      true ->
        {:ok,
         %{
           account_id: identity.account_id,
           profile_id: profile_id,
           device_id: device.id,
           device_public_key: device.device_public_key
         }}
    end
  end

  defp ensure_noise_device_matches(_challenge, nil), do: :ok

  defp ensure_noise_device_matches(%Challenge{issued_for: issued_for}, %{session: session}) do
    cond do
      not is_binary(issued_for) ->
        {:error, {:noise_handshake, :noise_device_missing}}

      String.trim(issued_for) == "" ->
        {:error, {:noise_handshake, :noise_device_missing}}

      true ->
        provided = String.trim(issued_for)

        try do
          expected = Handshake.device_key(session)

          if constant_time_compare?(expected, provided) do
            :ok
          else
            {:error, {:noise_handshake, :noise_device_mismatch}}
          end
        rescue
          ArgumentError -> {:error, {:noise_handshake, :noise_device_unknown}}
        end
    end
  end

  defp ensure_actor_account(%NoiseActor{account_id: actor_account_id}, account_id) do
    if actor_account_id == to_string(account_id) do
      :ok
    else
      {:error, :account_mismatch}
    end
  end

  defp maybe_reassign_device(%NoiseActor{device_id: nil}, _profile), do: {:ok, nil}

  defp maybe_reassign_device(%NoiseActor{device_id: device_id}, profile) when is_binary(device_id) do
    device = Accounts.get_device!(device_id)

    cond do
      device.account_id != profile.account_id -> {:error, :device_mismatch}
      true ->
        case Accounts.update_device(device, %{profile_id: profile.id}) do
          {:ok, updated} -> {:ok, updated}
          {:error, reason} -> {:error, reason}
        end
    end
  rescue
    NoResultsError -> {:error, :unknown_device}
  end

  defp maybe_reassign_device(_actor, _profile), do: {:ok, nil}

  defp constant_time_compare?(a, b) when is_binary(a) and is_binary(b) do
    byte_size(a) == byte_size(b) and Plug.Crypto.secure_compare(a, b)
  end

  defp constant_time_compare?(_a, _b), do: false

  defp maybe_put_noise_session(result, nil), do: result

  defp maybe_put_noise_session(result, %{id: id, token: token}) do
    Map.put(result, :noise_session, %{id: id, token: token})
  end

  defp emit_handshake_event(event, started_at, metadata) do
    measurements = %{duration: handshake_duration(started_at)}
    :telemetry.execute([:messngr, :auth, :noise, :handshake, event], measurements, metadata)
  end

  defp handshake_failure_metadata(bindings, reason) do
    bindings
    |> Enum.into(%{})
    |> Map.take([:session_id])
    |> Map.put(:reason, reason)
  end

  defp handshake_duration(started_at) when is_integer(started_at) do
    System.monotonic_time()
    |> Kernel.-(started_at)
    |> System.convert_time_unit(:native, :microsecond)
  end

  defp handshake_duration(_started_at), do: 0

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

  defp throttle_challenge_requests(channel, target) do
    bucket = "#{channel}:#{target}"

    case RateLimiter.check(:auth_challenge, bucket) do
      :ok -> :ok
      {:error, :rate_limited} -> {:error, :too_many_requests}
      {:error, reason} -> {:error, {:rate_limit_error, reason}}
    end
  end

  defp deliver_challenge(challenge, code) do
    case Notifier.deliver_challenge(challenge, code) do
      :ok -> :ok
      {:error, reason} ->
        Repo.delete(challenge)
        {:error, reason}
    end
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
