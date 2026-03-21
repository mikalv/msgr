defmodule MessngrWeb.Plugs.SessionContextTest do
  use MessngrWeb.ConnCase, async: true

  alias Messngr.Accounts

  setup %{conn: conn} do
    {:ok, account} = Accounts.create_account(%{"display_name" => "Plug Test"})
    profile = hd(account.profiles)

    %{conn: conn, account: account, profile: profile}
  end

  describe "valid JWT" do
    test "assigns current_account and current_profile", %{
      conn: conn,
      account: account,
      profile: profile
    } do
      conn =
        conn
        |> attach_jwt_session(account, profile)
        |> get("/api/settings")

      # If the plug worked, the controller runs and we get a 200
      assert json_response(conn, 200)
      assert conn.assigns[:current_account].id == account.id
      assert conn.assigns[:current_profile].id == profile.id
    end
  end

  describe "invalid JWT" do
    test "returns 401 for garbage token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer not.a.valid.jwt.token")
        |> get("/api/settings")

      assert json_response(conn, 401)
    end

    test "returns 401 for expired token", %{conn: conn, account: account, profile: profile} do
      resource = %{id: account.id}

      {:ok, expired_token, _claims} =
        AuthProvider.Guardian.encode_and_sign(
          resource,
          %{"pid" => profile.id, "ten" => %{}, "hdl" => "test"},
          token_type: "access",
          ttl: {-1, :minute}
        )

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{expired_token}")
        |> get("/api/settings")

      assert json_response(conn, 401)
    end

    test "returns 401 when Authorization header is missing", %{conn: conn} do
      conn = get(conn, "/api/settings")
      assert json_response(conn, 401)
    end

    test "returns 401 when account_id in JWT does not exist", %{conn: conn, profile: profile} do
      fake_account_id = Ecto.UUID.generate()
      resource = %{id: fake_account_id}

      {:ok, token, _claims} =
        AuthProvider.Guardian.encode_and_sign(
          resource,
          %{"pid" => profile.id, "ten" => %{}, "hdl" => "ghost"},
          token_type: "access",
          ttl: {15, :minute}
        )

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> get("/api/settings")

      assert json_response(conn, 401)
    end
  end
end
