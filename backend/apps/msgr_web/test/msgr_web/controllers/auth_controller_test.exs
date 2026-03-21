defmodule MessngrWeb.AuthControllerTest do
  use MessngrWeb.ConnCase, async: true

  # ── Challenge ────────────────────────────────────────────────

  describe "POST /api/v1/auth/challenge" do
    test "creates challenge for email and returns id + debug_code", %{conn: conn} do
      conn =
        post(conn, "/api/v1/auth/challenge", %{
          channel: "email",
          identifier: "challenge@example.com"
        })

      resp = json_response(conn, 201)
      assert is_binary(resp["id"])
      assert is_binary(resp["debug_code"])
      assert resp["channel"] == "email"
      assert String.contains?(resp["target_hint"], "@example.com")
    end

    test "creates challenge for phone", %{conn: conn} do
      conn =
        post(conn, "/api/v1/auth/challenge", %{
          channel: "phone",
          identifier: "+4712345678"
        })

      resp = json_response(conn, 201)
      assert is_binary(resp["id"])
      assert resp["channel"] == "phone"
    end

    test "returns error for unsupported channel", %{conn: conn} do
      conn =
        post(conn, "/api/v1/auth/challenge", %{
          channel: "pigeon",
          identifier: "bird@sky.com"
        })

      assert json_response(conn, 400)
    end

    test "returns error for invalid email", %{conn: conn} do
      conn =
        post(conn, "/api/v1/auth/challenge", %{
          channel: "email",
          identifier: "not-an-email"
        })

      assert json_response(conn, 400)
    end
  end

  # ── Verify ──────────────────────────────────────────────────

  describe "POST /api/v1/auth/verify" do
    test "valid code returns account, tokens, and identity", %{conn: conn} do
      {:ok, challenge, code} =
        Messngr.start_auth_challenge(%{
          "channel" => "email",
          "identifier" => "verify-jwt@example.com"
        })

      conn =
        post(conn, "/api/v1/auth/verify", %{
          challenge_id: challenge.id,
          code: code,
          display_name: "Verify JWT"
        })

      resp = json_response(conn, 200)

      assert %{
               "account" => %{"id" => _, "display_name" => "Verify JWT"},
               "identity" => %{"verified_at" => _},
               "access_token" => access_token,
               "refresh_token" => refresh_token
             } = resp

      assert is_binary(access_token)
      assert is_binary(refresh_token)
    end

    test "wrong code returns error", %{conn: conn} do
      {:ok, challenge, _code} =
        Messngr.start_auth_challenge(%{
          "channel" => "email",
          "identifier" => "wrong-code@example.com"
        })

      conn =
        post(conn, "/api/v1/auth/verify", %{
          challenge_id: challenge.id,
          code: "000000"
        })

      assert json_response(conn, 400)
    end

    test "expired challenge returns error", %{conn: conn} do
      {:ok, challenge, code} =
        Messngr.start_auth_challenge(%{
          "channel" => "email",
          "identifier" => "expired@example.com"
        })

      # Force-expire the challenge
      challenge
      |> Ecto.Changeset.change(%{expires_at: DateTime.add(DateTime.utc_now(), -600, :second)})
      |> Messngr.Repo.update!()

      conn =
        post(conn, "/api/v1/auth/verify", %{
          challenge_id: challenge.id,
          code: code
        })

      assert json_response(conn, 400)
    end

    test "missing params returns error", %{conn: conn} do
      conn = post(conn, "/api/v1/auth/verify", %{})
      assert json_response(conn, 400)
    end
  end

  # ── Refresh ─────────────────────────────────────────────────

  describe "POST /api/v1/auth/refresh" do
    setup %{conn: conn} do
      # Create an account via the challenge flow
      {:ok, challenge, code} =
        Messngr.start_auth_challenge(%{
          "channel" => "email",
          "identifier" => "refresh-#{System.unique_integer([:positive])}@example.com"
        })

      {:ok, result} = Messngr.verify_auth_challenge(challenge.id, code, %{})

      %{
        conn: conn,
        account: result.account,
        access_token: result.access_token,
        refresh_token: result.refresh_token
      }
    end

    test "valid refresh token returns new access token", %{
      conn: conn,
      refresh_token: refresh_token
    } do
      conn =
        post(conn, "/api/v1/auth/refresh", %{refresh_token: refresh_token})

      resp = json_response(conn, 200)
      assert is_binary(resp["access_token"])
    end

    test "invalid token returns 401", %{conn: conn} do
      conn =
        post(conn, "/api/v1/auth/refresh", %{refresh_token: "garbage"})

      assert json_response(conn, 401)
    end

    test "using access token as refresh returns 401", %{
      conn: conn,
      access_token: access_token
    } do
      conn =
        post(conn, "/api/v1/auth/refresh", %{refresh_token: access_token})

      assert json_response(conn, 401)
    end

    test "missing refresh_token param returns 400", %{conn: conn} do
      conn = post(conn, "/api/v1/auth/refresh", %{})
      assert json_response(conn, 400)
    end
  end

  # ── OIDC ────────────────────────────────────────────────────

  describe "POST /api/v1/auth/oidc" do
    test "completes oidc", %{conn: conn} do
      conn =
        post(conn, "/api/v1/auth/oidc", %{
          provider: "example",
          subject: "oidc-#{System.unique_integer([:positive])}",
          email: "oidc@example.com",
          name: "OIDC"
        })

      assert %{
               "account" => %{
                 "email" => "oidc@example.com",
                 "profiles" => [%{"name" => "OIDC"} | _]
               },
               "profile" => %{"name" => "OIDC"}
             } = json_response(conn, 200)
    end
  end
end
