defmodule MessngrWeb.ConversationControllerTest do
  use MessngrWeb.ConnCase, async: true

  alias Messngr.Accounts

  setup %{conn: conn} do
    {:ok, current_account} = Accounts.create_account(%{"display_name" => "Kari"})
    {:ok, other_account} = Accounts.create_account(%{"display_name" => "Ola"})

    current_profile = hd(current_account.profiles)
    target_profile = hd(other_account.profiles)

    conn =
      conn
      |> put_req_header("x-account-id", current_account.id)
      |> put_req_header("x-profile-id", current_profile.id)

    {:ok,
     conn: conn,
     target_profile: target_profile,
     current_profile: current_profile,
     current_account: current_account}
  end

  test "creates or returns conversation", %{conn: conn, target_profile: target_profile} do
    conn = post(conn, ~p"/api/conversations", %{target_profile_id: target_profile.id})

    assert %{"data" => %{"id" => id, "participants" => participants}} = json_response(conn, 200)
    assert is_binary(id)
    assert length(participants) == 2
  end

  test "missing header returns unauthorized", %{target_profile: target_profile} do
    conn = build_conn()
    conn = post(conn, ~p"/api/conversations", %{target_profile_id: target_profile.id})

    assert conn.status == 401
  end
end
