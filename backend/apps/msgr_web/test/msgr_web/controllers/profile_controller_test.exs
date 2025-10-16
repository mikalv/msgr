defmodule MessngrWeb.ProfileControllerTest do
  use MessngrWeb.ConnCase, async: true

  alias Messngr.Accounts

  setup %{conn: conn} do
    {:ok, account} = Accounts.create_account(%{"display_name" => "Ingrid"})
    profile = List.first(account.profiles)
    {:ok, other} = Accounts.create_profile(%{"name" => "Jobb", "mode" => :work, "account_id" => account.id})
    {conn, session} = attach_noise_session(conn, account, profile)

    {:ok,
     conn: conn,
     account: account,
     profile: profile,
     other: other,
     device: session.device,
     token: session.token}
  end

  test "lists profiles", %{conn: conn, profile: profile, other: other} do
    response =
      conn
      |> get(~p"/api/profiles")
      |> json_response(200)

    assert [%{"id" => ^profile_id} | _] = response["data"]
    assert profile_id == profile.id
    assert Enum.any?(response["data"], &(&1["id"] == other.id))
    assert Enum.any?(response["data"], &(&1["is_active"]))
  end

  test "creates profile with preferences", %{conn: conn, account: account} do
    params = %{
      "name" => "Familie",
      "mode" => "family",
      "theme" => %{"primary" => "#AA5500", "mode" => "dark"},
      "notification_policy" => %{"allow_push" => false},
      "security_policy" => %{"requires_pin" => true}
    }

    response =
      conn
      |> post(~p"/api/profiles", %{"profile" => params})
      |> json_response(201)

    id = response["data"]["id"]
    created = Accounts.get_profile!(id)
    assert created.account_id == account.id
    assert created.name == "Familie"
    assert created.theme["primary"] == "#AA5500"
    assert created.security_policy["requires_pin"]
  end

  test "updates profile policies", %{conn: conn, other: other} do
    response =
      conn
      |> patch(~p"/api/profiles/#{other.id}", %{
        "profile" => %{"notification_policy" => %{"allow_email" => true}}
      })
      |> json_response(200)

    assert response["data"]["notification_policy"]["allow_email"]
  end

  test "deletes secondary profile", %{conn: conn, other: other} do
    conn = delete(conn, ~p"/api/profiles/#{other.id}")
    assert response(conn, 204)
  end

  test "prevents deleting active profile", %{conn: conn, profile: profile} do
    response =
      conn
      |> delete(~p"/api/profiles/#{profile.id}")
      |> json_response(409)

    assert response["error"] == "cannot_delete_active_profile"
  end

  test "prevents deleting last remaining profile", %{conn: conn, profile: profile, other: other} do
    assert response(delete(conn, ~p"/api/profiles/#{other.id}"), 204)

    response =
      conn
      |> delete(~p"/api/profiles/#{profile.id}")
      |> json_response(409)

    assert response["error"] == "cannot_delete_last_profile"
  end

  test "switches active profile", %{conn: conn, account: account, profile: profile, other: other, device: device, token: token} do
    response =
      conn
      |> post(~p"/api/profiles/#{other.id}/switch")
      |> json_response(200)

    assert response["data"]["profile"]["id"] == other.id
    assert response["data"]["noise_session"]["token"] == token

    updated_device = Accounts.get_device!(device.id)
    assert updated_device.profile_id == other.id

    assert get_session(conn, :noise_session_token) == token
  end

  test "returns not found when switching to foreign profile", %{conn: conn} do
    assert response(conn |> post(~p"/api/profiles/#{Ecto.UUID.generate()}/switch"), 404)
  end
end
