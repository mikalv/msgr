defmodule MessngrWeb.FamilyShoppingListControllerTest do
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

  test "creates shopping list and item", %{conn: conn, family: family} do
    conn = post(conn, ~p"/api/families/#{family.id}/shopping_lists", %{list: %{name: "Helg"}})
    response = json_response(conn, 201)
    assert %{"data" => %{"name" => "Helg", "items" => []}} = response

    list_id = get_in(response, ["data", "id"])

    conn =
      post(conn, ~p"/api/families/#{family.id}/shopping_lists/#{list_id}/items", %{
        item: %{name: "Egg", quantity: "12"}
      })

    assert %{"data" => %{"name" => "Egg", "checked" => false}} = json_response(conn, 201)

    conn = get(conn, ~p"/api/families/#{family.id}/shopping_lists")
    assert %{"data" => [%{"items" => [%{"name" => "Egg"}]}]} = json_response(conn, 200)
  end
end
