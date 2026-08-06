defmodule MessngrWeb.FamilyTodoListControllerTest do
  use MessngrWeb.ConnCase, async: true

  alias Messngr.Accounts
  alias FamilySpace

  setup %{conn: conn} do
    {:ok, account} = Accounts.create_account(%{"display_name" => "Forelder"})
    profile = hd(account.profiles)
    {:ok, family} = FamilySpace.create_space(profile.id, %{"name" => "Familie"})

    {conn, _session} = attach_noise_session(conn, account, profile)

    {:ok, conn: conn, profile: profile, family: family}
  end

  test "creates todo list and marks complete", %{conn: conn, family: family, profile: profile} do
    conn = post(conn, ~p"/api/families/#{family.id}/todo_lists", %{list: %{name: "Oppgaver"}})
    response = json_response(conn, 201)
    assert %{"data" => %{"name" => "Oppgaver", "items" => []}} = response

    list_id = get_in(response, ["data", "id"])

    conn =
      post(conn, ~p"/api/families/#{family.id}/todo_lists/#{list_id}/items", %{
        item: %{content: "Handle", assignee_profile_id: profile.id}
      })

    item = json_response(conn, 201)
    assert %{"data" => %{"status" => "pending"}} = item
    item_id = get_in(item, ["data", "id"])

    conn =
      put(conn, ~p"/api/families/#{family.id}/todo_lists/#{list_id}/items/#{item_id}", %{
        item: %{status: "done"}
      })

    assert %{"data" => %{"status" => "done"}} = json_response(conn, 200)
  end
end
