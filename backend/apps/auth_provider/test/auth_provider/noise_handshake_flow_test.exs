defmodule AuthProvider.NoiseHandshakeFlowTest do
  use Messngr.DataCase

  alias Messngr.Auth
  alias Messngr.FeatureFlags
  alias Messngr.Noise.Handshake
  alias Messngr.Transport.Noise.Session

  setup do
    original_flag = FeatureFlags.require_noise_handshake?()
    FeatureFlags.put(:noise_handshake_required, true)

    on_exit(fn ->
      FeatureFlags.put(:noise_handshake_required, original_flag)
    end)

    :ok
  end

  test "OTP verification fails without handshake payload" do
    %{session: session, device_key: device_key} = establish_handshake()

    {:ok, challenge, code} =
      Auth.start_challenge(%{
        "channel" => "email",
        "identifier" => "auth-provider@example.com",
        "device_id" => device_key
      })

    assert {:error, {:noise_handshake, {:missing, "noise_session_id"}}} =
             Auth.verify_challenge(challenge.id, code, %{})

    # Clean up persisted session to avoid leaking into other tests
    :ok = Messngr.Transport.Noise.Registry.delete(session.id)
  end

  test "OTP verification succeeds when handshake metadata matches" do
    %{session: session, signature: signature, device_key: device_key} = establish_handshake()

    {:ok, challenge, code} =
      Auth.start_challenge(%{
        "channel" => "email",
        "identifier" => "auth-provider-success@example.com",
        "device_id" => device_key
      })

    assert {:ok, %{noise_session: %{id: ^Session.id(session), token: token}}} =
             Auth.verify_challenge(challenge.id, code, %{
               "noise_session_id" => Session.id(session),
               "noise_signature" => signature,
               "last_handshake_at" => DateTime.utc_now()
             })

    assert {:ok, _raw} = Messngr.Noise.SessionStore.decode_token(token)
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
      device_key: Handshake.device_key(session)
    }
  end
end
