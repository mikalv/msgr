defmodule Messngr.Auth.NoiseHandshakeFlowTest do
  use Messngr.DataCase

  alias Messngr.Auth
  alias Messngr.FeatureFlags
  alias Messngr.Noise.{Handshake, SessionStore}
  alias Messngr.Transport.Noise.Session

  setup do
    original_flag = FeatureFlags.require_noise_handshake?()
    FeatureFlags.put(:noise_handshake_required, true)

    on_exit(fn ->
      FeatureFlags.put(:noise_handshake_required, original_flag)
    end)

    :ok
  end

  describe "verify_challenge/3 with Noise handshake" do
    test "completes OTP flow, registers session and returns token" do
      %{session: session, signature: signature, device_key: device_key} = establish_handshake()

      {:ok, challenge, code} =
        Auth.start_challenge(%{
          "channel" => "email",
          "identifier" => "noise-user@example.com",
          "device_id" => device_key
        })

      assert {:ok, %{account: account, identity: identity, noise_session: noise}} =
               Auth.verify_challenge(challenge.id, code, %{
                 "display_name" => "Noise Device",
                 "noise_session_id" => Session.id(session),
                 "noise_signature" => signature,
                 "last_handshake_at" => DateTime.utc_now()
               })

      session_id = Session.id(session)
      assert %{id: ^session_id, token: token} = noise
      assert is_binary(token)

      {:ok, raw_token} = SessionStore.decode_token(token)
      assert {:ok, stored_session, actor} = SessionStore.fetch(raw_token)

      assert actor.account_id == account.id
      assert actor.profile_id in Enum.map(account.profiles, & &1.id)
      assert actor.device_id == List.first(account.devices).id
      assert actor.device_public_key == device_key

      assert Session.token(stored_session) == raw_token
      assert identity.account.id == account.id
      assert Enum.any?(account.devices, &(&1.device_public_key == device_key))
    end

    test "fails when signature is invalid" do
      %{session: session, signature: signature, device_key: device_key} = establish_handshake()

      {:ok, challenge, code} =
        Auth.start_challenge(%{
          "channel" => "email",
          "identifier" => "noise-bad-signature@example.com",
          "device_id" => device_key
        })

      assert {:error, {:noise_handshake, :invalid_noise_signature}} =
               Auth.verify_challenge(challenge.id, code, %{
                 "noise_session_id" => Session.id(session),
                 "noise_signature" => signature <> "corrupted"
               })
    end

    test "fails when session is no longer present" do
      %{session: session, signature: _signature, device_key: device_key} = establish_handshake()

      {:ok, challenge, code} =
        Auth.start_challenge(%{
          "channel" => "email",
          "identifier" => "noise-expired@example.com",
          "device_id" => device_key
        })

      :ok = Messngr.Transport.Noise.Registry.delete(session.id)

      assert {:error, {:noise_handshake, :noise_session_not_found}} =
               Auth.verify_challenge(challenge.id, code, %{
                 "noise_session_id" => Session.id(session),
                 "noise_signature" => Handshake.encoded_signature(session)
               })
    end

    test "accepts handshake after session rekey" do
      %{session: _session, signature: _signature, device_key: device_key, device_public: device_public} =
        establish_handshake()

      rekeyed_session =
        Session.established_session(
          actor: %{account_id: "bootstrap", profile_id: "bootstrap"},
          token: :crypto.strong_rand_bytes(32),
          handshake_hash: :crypto.strong_rand_bytes(32),
          remote_static: device_public,
          prologue: "msgr-test/v1"
        )

      {:ok, rekeyed} = Handshake.persist(rekeyed_session)
      new_signature = Handshake.encoded_signature(rekeyed)

      {:ok, challenge, code} =
        Auth.start_challenge(%{
          "channel" => "email",
          "identifier" => "noise-rekey@example.com",
          "device_id" => device_key
        })

      assert {:ok, %{noise_session: %{token: token}}} =
               Auth.verify_challenge(challenge.id, code, %{
                 "noise_session_id" => Session.id(rekeyed),
                 "noise_signature" => new_signature,
                 "last_handshake_at" => DateTime.utc_now()
               })

      {:ok, raw_token} = SessionStore.decode_token(token)
      assert {:ok, _session, actor} = SessionStore.fetch(raw_token)
      assert actor.device_public_key == device_key
    end
  end

  defp establish_handshake do
    device_private = :crypto.strong_rand_bytes(32)
    {device_public, _} = :crypto.generate_key(:ecdh, :x25519, device_private)

    session =
      Session.established_session(
        actor: %{account_id: "bootstrap", profile_id: "bootstrap"},
        token: :crypto.strong_rand_bytes(32),
        handshake_hash: :crypto.strong_rand_bytes(32),
        remote_static: device_public,
        prologue: "msgr-test/v1"
      )

    {:ok, session} = Handshake.persist(session)

    %{
      session: session,
      signature: Handshake.encoded_signature(session),
      device_key: Handshake.device_key(session),
      device_public: device_public
    }
  end
end
