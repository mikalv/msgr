defmodule MessngrWeb.AuthControllerNoiseTest do
  use MessngrWeb.ConnCase

  alias Messngr.Auth
  alias Messngr.FeatureFlags
  alias Messngr.Noise.Handshake
  alias Messngr.Transport.Noise.{Session, TestHelpers}
  alias MessngrWeb.Plugs.NoiseSession

  setup %{conn: conn} do
    original_flag = FeatureFlags.require_noise_handshake?()
    FeatureFlags.put(:noise_handshake_required, true)

    on_exit(fn ->
      FeatureFlags.put(:noise_handshake_required, original_flag)
    end)

    {:ok, conn: conn}
  end

  test "POST /api/auth/verify returns 400 without handshake", %{conn: conn} do
    %{device_key: device_key} = establish_handshake()

    {:ok, challenge, code} =
      Auth.start_challenge(%{
        "channel" => "email",
        "identifier" => "noise-api@example.com",
        "device_id" => device_key
      })

    conn =
      post(conn, ~p"/api/auth/verify", %{
        "challenge_id" => challenge.id,
        "code" => code
      })

    assert %{"error" => "noise_handshake", "reason" => reason} = json_response(conn, 400)
    assert reason in ["missing_noise_session_id", "missing_noise_signature"]
  end

  test "POST /api/auth/verify succeeds after handshake", %{conn: conn} do
    %{session: session, signature: signature, device_key: device_key} = establish_handshake()

    {:ok, challenge, code} =
      Auth.start_challenge(%{
        "channel" => "email",
        "identifier" => "noise-api-success@example.com",
        "device_id" => device_key
      })

    payload = %{
      "challenge_id" => challenge.id,
      "code" => code,
      "noise_session_id" => Session.id(session),
      "noise_signature" => signature,
      "last_handshake_at" => DateTime.utc_now()
    }

    conn = post(conn, ~p"/api/auth/verify", payload)

    assert %{"noise_session" => %{"token" => token, "id" => Session.id(session)}} =
             json_response(conn, 200)

    assert {:ok, actor} = NoiseSession.verify_token(token)
    assert actor.account_id
    assert actor.device_public_key == device_key
  end

  defp establish_handshake do
    session = TestHelpers.build_session(:new)
    client_state = TestHelpers.client_state(:nx)
    {session, _client_state} = TestHelpers.handshake_pair(session, client_state)
    {:ok, session} = Handshake.persist(session)

    %{
      session: session,
      signature: Handshake.encoded_signature(session),
      device_key: Handshake.device_key(session)
    }
  end
end
