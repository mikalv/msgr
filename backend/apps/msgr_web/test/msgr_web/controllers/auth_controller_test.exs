defmodule MessngrWeb.AuthControllerTest do
  use MessngrWeb.ConnCase, async: true

  describe "POST /api/auth/challenge" do
    test "creates challenge for email", %{conn: conn} do
      conn = post(conn, "/api/auth/challenge", %{channel: "email", identifier: "test@example.com"})

      assert %{"id" => id, "channel" => "email", "target_hint" => hint} = json_response(conn, 201)
      assert String.ends_with?(hint, "example.com")
      assert is_binary(id)
    end
  end

  describe "POST /api/auth/verify" do
    test "verifies challenge", %{conn: conn} do
      {:ok, challenge, code} = Messngr.start_auth_challenge(%{"channel" => "email", "identifier" => "verify@example.com"})

      conn =
        post(conn, "/api/auth/verify", %{challenge_id: challenge.id, code: code, display_name: "Verify"})

      assert %{"account" => %{"display_name" => "Verify"}} = json_response(conn, 200)
    end
  end

  describe "POST /api/auth/oidc" do
    test "completes oidc", %{conn: conn} do
      conn =
        post(conn, "/api/auth/oidc", %{
          provider: "example",
          subject: "123",
          email: "oidc@example.com",
          name: "OIDC"
        })

      assert %{"account" => %{"email" => "oidc@example.com"}} = json_response(conn, 200)
    end
  end
end

