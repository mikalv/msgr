defmodule Messngr.Auth do
  @moduledoc """
  Handles passwordless OTP and federated sign-in flows for Messngr clients.
  """

  require Logger

  alias Messngr.Accounts
  alias Messngr.Accounts.Identity
  alias Messngr.Auth.Challenge
  alias Messngr.Auth.Notifier
  alias Messngr.FeatureFlags
  alias Messngr.Repo
  alias Messngr.RateLimiter

  alias Ecto.NoResultsError

  @challenge_ttl_minutes 10
  @max_verify_attempts 5

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
    # Rust Gateway handles Noise protocol
    # This function verifies OTP and binds the account to the Noise session
    challenge = Repo.get!(Challenge, id)

    with :ok <- ensure_not_consumed(challenge),
         :ok <- ensure_not_expired(challenge),
         :ok <- ensure_attempts_remaining(challenge),
         :ok <- compare_or_record_failure(challenge, code) do
      # UUID from Rust Gateway
      session_id = Map.get(attrs, "session_id")
      # Token from Rust Gateway
      session_token = Map.get(attrs, "session_token")

      Repo.transaction(fn ->
        # Reload to ensure we still have a valid challenge inside the transaction
        challenge = Repo.get!(Challenge, id)

        with :ok <- ensure_not_consumed(challenge),
             :ok <- ensure_not_expired(challenge),
             :ok <- ensure_attempts_remaining(challenge),
             :ok <- compare_code(challenge, code),
             {:ok, identity} <- upsert_identity_from_challenge(challenge, attrs),
             {:ok, _} <- mark_challenge_consumed(challenge),
             {:ok, identity} <-
               Accounts.verify_identity(identity, %{last_challenged_at: challenge.inserted_at}),
             {:ok, %{identity: identity, device: device}} <-
               Accounts.attach_device_for_identity(identity, device_attrs_from(challenge, attrs)),
             :ok <-
               bind_noise_session_to_account(
                 session_id,
                 session_token,
                 identity.account,
                 Map.get(identity, :profile),
                 device
               ) do
          account = identity.account
          default_profile = List.first(List.wrap(account.profiles))
          default_profile_id = default_profile && default_profile.id

          # Build team memberships map and issue JWT tokens
          {access_token, refresh_token} = issue_jwt_tokens(account, default_profile_id)

          %{
            account: account,
            identity: identity,
            device: device,
            session_id: session_id,
            access_token: access_token,
            refresh_token: refresh_token
          }
        else
          {:error, reason} -> Repo.rollback(reason)
          error -> Repo.rollback(error)
        end
      end)
    end
  end

  @doc """
  Issues a new access token / refresh token pair for the given account.
  """
  def issue_jwt_tokens(account, default_profile_id) do
    team_memberships = build_team_memberships_map(account.id)

    resource = %{id: account.id}

    custom_claims = %{
      "ten" => team_memberships,
      "pid" => default_profile_id,
      "hdl" => account.handle || account.display_name
    }

    {:ok, access_token, _claims} =
      AuthProvider.Guardian.encode_and_sign(
        resource,
        custom_claims,
        token_type: "access",
        ttl: {15, :minute}
      )

    {:ok, refresh_token, _claims} =
      AuthProvider.Guardian.encode_and_sign(
        resource,
        custom_claims,
        token_type: "refresh",
        ttl: {30, :day}
      )

    {access_token, refresh_token}
  end

  @doc """
  Refreshes an access token using a valid refresh token.

  Returns `{:ok, new_access_token}` or `{:error, reason}`.
  """
  def refresh_access_token(refresh_token) do
    case AuthProvider.Guardian.decode_and_verify(refresh_token, %{"typ" => "refresh"}) do
      {:ok, claims} ->
        account_id = claims["sub"]

        case Accounts.get_account_safe(account_id) do
          {:ok, account} ->
            default_profile_id = claims["pid"]
            team_memberships = build_team_memberships_map(account.id)

            custom_claims = %{
              "ten" => team_memberships,
              "pid" => default_profile_id,
              "hdl" => account.handle || account.display_name
            }

            {:ok, access_token, _claims} =
              AuthProvider.Guardian.encode_and_sign(
                %{id: account.id},
                custom_claims,
                token_type: "access",
                ttl: {15, :minute}
              )

            {:ok, access_token}

          {:error, _} ->
            {:error, :account_not_found}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Authenticates a bot by email using a pre-shared secret.
  Finds or creates the account and issues JWT tokens without OTP.
  """
  def authenticate_bot(email) do
    display_name =
      email
      |> String.split("@")
      |> List.first()
      |> String.replace(~r/[._-]/, " ")
      |> String.split()
      |> Enum.map(&String.capitalize/1)
      |> Enum.join(" ")

    Repo.transaction(fn ->
      with {:ok, identity} <-
             Accounts.ensure_identity(%{
               kind: :email,
               value: email,
               display_name: display_name,
               email: email,
               phone_number: nil
             }),
           account <- Repo.preload(identity.account, :profiles) do
        default_profile = List.first(List.wrap(account.profiles))
        default_profile_id = default_profile && default_profile.id

        {access_token, refresh_token} = issue_jwt_tokens(account, default_profile_id)

        %{
          account: account,
          identity: identity,
          access_token: access_token,
          refresh_token: refresh_token
        }
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
  end

  defp build_team_memberships_map(account_id) do
    import Ecto.Query

    from(tm in Messngr.Teams.TeamMembership,
      where: tm.account_id == ^account_id,
      join: t in assoc(tm, :team),
      select: {t.slug, %{role: tm.role, team_id: t.id}}
    )
    |> Repo.all()
    |> Enum.into(%{})
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

  # Noise protocol removed - handled by Rust Gateway
  # These functions are stubs to prevent compilation errors

  defp maybe_resolve_handshake(_attrs) do
    {:ok, nil}
  end

  defp fetch_noise_session(_session_id) do
    {:error, :noise_removed}
  end

  defp decode_noise_signature(_value) do
    {:error, :noise_removed}
  end

  defp verify_noise_signature(_session, _signature) do
    {:error, :noise_removed}
  end

  defp maybe_finalize_handshake(_handshake, _identity, _device) do
    {:ok, nil}
  end

  # TODO: Reimplement switch_profile without Noise SessionStore
  # Rust Gateway now handles Noise sessions
  def switch_profile(_encoded_token, _account_id, _profile_id, _opts \\ []) do
    {:error, :noise_removed_use_rust_gateway}
  end

  # Noise-related helper functions removed
  # Rust Gateway now handles all Noise protocol logic

  defp bind_noise_session_to_account(nil, _token, _account, _profile, _device) do
    # No session ID provided - skip binding
    :ok
  end

  defp bind_noise_session_to_account(session_id, session_token, account, profile, device)
       when is_binary(session_id) and is_binary(session_token) do
    require Logger

    Logger.info("Binding Noise session to account",
      session_id: session_id,
      account_id: account.id,
      profile_id: profile && profile.id,
      device_id: device && device.id
    )

    # Call Rust Gateway via gRPC to bind account to session
    Messngr.RustGateway.Client.bind_account(%{
      session_id: session_id,
      session_token: session_token,
      account_id: account.id,
      profile_id: profile && profile.id,
      device_id: device && device.id
    })
  end

  defp bind_noise_session_to_account(_session_id, _token, _account, _profile, _device) do
    # Invalid parameters
    {:error, :invalid_session_binding_parameters}
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

  defp throttle_challenge_requests(channel, target) do
    bucket = "#{channel}:#{target}"

    case RateLimiter.check(:auth_challenge, bucket) do
      :ok -> :ok
      {:error, :rate_limited} -> {:error, :too_many_requests}
      {:error, reason} -> {:error, {:rate_limit_error, reason}}
    end
  end

  defp deliver_challenge(challenge, code) do
    Logger.info("Delivering OTP to #{challenge.channel}:#{challenge.target}")

    case Notifier.deliver_challenge(challenge, code) do
      :ok ->
        :ok

      {:error, reason} ->
        Repo.delete(challenge)
        {:error, reason}
    end
  end

  defp upsert_identity_from_challenge(challenge, attrs) do
    display_name =
      Map.get(attrs, "display_name") || derive_display_name(challenge)

    Accounts.ensure_identity(%{
      kind: challenge.channel,
      value: challenge.target,
      display_name: display_name,
      email: channel_email(challenge),
      phone_number: channel_phone(challenge)
    })
  end

  defp derive_display_name(%Challenge{channel: :email, target: target}) do
    local =
      target
      |> String.split("@")
      |> List.first()
      |> String.replace(~r/[._-]/, " ")
      |> String.split()
      |> Enum.map(&String.capitalize/1)
      |> Enum.join(" ")

    if byte_size(local) >= 2, do: local, else: target
  end

  defp derive_display_name(%Challenge{channel: :phone, target: target}) do
    "User #{String.slice(target, -4, 4)}"
  end

  defp derive_display_name(_), do: "User"

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

  defp ensure_attempts_remaining(%Challenge{attempt_count: count})
       when is_integer(count) and count >= @max_verify_attempts do
    {:error, :too_many_attempts}
  end

  defp ensure_attempts_remaining(_), do: :ok

  defp compare_or_record_failure(challenge, code) do
    case compare_code(challenge, code) do
      :ok ->
        :ok

      {:error, :invalid_code} ->
        record_failed_attempt(challenge)
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

  defp record_failed_attempt(%Challenge{id: id}) do
    import Ecto.Query

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # Atomic increment so concurrent wrong guesses cannot lose attempts.
    {updated, rows} =
      from(c in Challenge,
        where: c.id == ^id and is_nil(c.consumed_at),
        select: c.attempt_count
      )
      |> Repo.update_all(inc: [attempt_count: 1])

    case {updated, rows} do
      {1, [count]} when is_integer(count) and count >= @max_verify_attempts ->
        from(c in Challenge, where: c.id == ^id and is_nil(c.consumed_at))
        |> Repo.update_all(set: [consumed_at: now])

        {:error, :too_many_attempts}

      {1, _} ->
        {:error, :invalid_code}

      {0, _} ->
        {:error, :too_many_attempts}
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
    :crypto.strong_rand_bytes(4)
    |> :binary.decode_unsigned()
    |> rem(1_000_000)
    |> Integer.to_string()
    |> String.pad_leading(6, "0")
  end

  defp hash_code(code) do
    secret = otp_hmac_secret()

    :crypto.mac(:hmac, :sha256, secret, code)
    |> Base.encode64()
  end

  defp otp_hmac_secret do
    case Application.get_env(:msgr, :otp_hmac_secret) do
      secret when is_binary(secret) and secret != "" ->
        secret

      _ ->
        Application.get_env(:msgr_web, MessngrWeb.Endpoint)[:secret_key_base] ||
          raise "OTP HMAC secret is not configured"
    end
  end
end
