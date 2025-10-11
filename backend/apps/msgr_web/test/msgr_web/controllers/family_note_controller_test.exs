defmodule MessngrWeb.FamilyNoteControllerTest do
  use MessngrWeb.ConnCase, async: true

  alias Messngr.Accounts
  alias FamilySpace

  setup %{conn: conn} do
    {:ok, account} = Accounts.create_account(%{"display_name" => "Forelder"})
    profile = hd(account.profiles)
    {:ok, family} = FamilySpace.create_space(profile.id, %{"name" => "Familie"})

    conn =
      conn
      |> put_req_header("x-account-id", account.id)
      |> put_req_header("x-profile-id", profile.id)

    {:ok, conn: conn, profile: profile, family: family}
  end

  test "creates, updates and filters notes", %{conn: conn, family: family} do
    conn =
      post(conn, ~p"/api/families/#{family.id}/notes", %{
        note: %{title: "Ukemeny", body: "Taco", pinned: true}
      })

    response = json_response(conn, 201)
    assert %{"data" => %{"title" => "Ukemeny", "pinned" => true}} = response
    note_id = get_in(response, ["data", "id"])

    conn =
      put(conn, ~p"/api/families/#{family.id}/notes/#{note_id}", %{
        note: %{title: "Ny meny", pinned: false}
      })

    assert %{"data" => %{"title" => "Ny meny", "pinned" => false}} = json_response(conn, 200)

    conn = get(conn, ~p"/api/families/#{family.id}/notes", %{pinned_only: true})
    assert %{"data" => []} = json_response(conn, 200)

    conn = get(conn, ~p"/api/families/#{family.id}/notes/#{note_id}")
    assert %{"data" => %{"id" => ^note_id}} = json_response(conn, 200)

    conn = delete(conn, ~p"/api/families/#{family.id}/notes/#{note_id}")
    assert response(conn, 204)
  end
end
