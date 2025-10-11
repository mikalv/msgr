defmodule MessngrWeb.FamilyControllerTest do
  use MessngrWeb.ConnCase, async: true

  alias Messngr.Accounts
  alias Messngr

  setup %{conn: conn} do
    {:ok, account} = Accounts.create_account(%{"display_name" => "Forelder"})
    profile = hd(account.profiles)

    conn =
      conn
      |> put_req_header("x-account-id", account.id)
      |> put_req_header("x-profile-id", profile.id)

    {:ok, conn: conn, profile: profile}
  end

  test "creates family", %{conn: conn} do
    conn = post(conn, ~p"/api/families", %{family: %{name: "Team A"}})

    assert %{"data" => %{"name" => "Team A", "slug" => "team-a"}} = json_response(conn, 201)
  end

  test "lists families for current profile", %{conn: conn, profile: profile} do
    {:ok, family} = Messngr.create_family(profile.id, %{"name" => "Familien"})

    conn = get(conn, ~p"/api/families")

    assert %{"data" => [%{"id" => ^family.id}]} = json_response(conn, 200)
  end

  test "manages events", %{conn: conn, profile: profile} do
    {:ok, family} = Messngr.create_family(profile.id, %{"name" => "Familie"})
    starts_at = DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()

    conn =
      post(conn, ~p"/api/families/#{family.id}/events", %{
        event: %{title: "Middag", starts_at: starts_at}
      })

    assert %{"data" => %{"title" => "Middag", "family_id" => ^family.id}} = json_response(conn, 201)

    conn = get(conn, ~p"/api/families/#{family.id}/events")
    assert %{"data" => [%{"title" => "Middag"}]} = json_response(conn, 200)
  end
end
