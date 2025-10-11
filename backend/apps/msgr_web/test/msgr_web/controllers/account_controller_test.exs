defmodule MessngrWeb.AccountControllerTest do
  use MessngrWeb.ConnCase, async: true

  alias Messngr.Accounts

  describe "POST /api/users" do
    test "creates account", %{conn: conn} do
      conn =
        post(conn, ~p"/api/users", %{
          "display_name" => "Kari",
          "email" => "kari@example.com"
        })

      assert %{"data" => %{"display_name" => "Kari", "profiles" => [%{"name" => "Privat"}]}} =
               json_response(conn, 201)
    end
  end

  describe "GET /api/users" do
    test "lists accounts", %{conn: conn} do
      {:ok, _account} = Accounts.create_account(%{"display_name" => "Kari"})

      conn = get(conn, ~p"/api/users")

      assert %{"data" => [_]} = json_response(conn, 200)
    end
  end
end
