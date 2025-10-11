defmodule FamilySpaceTest do
  use FamilySpace.DataCase, async: true

  alias FamilySpace
  alias FamilySpace.{Membership, ShoppingItem, TodoItem}
  alias Messngr.Accounts

  setup do
    {:ok, account} = Accounts.create_account(%{"display_name" => "Familiekonto"})
    parent = hd(account.profiles)
    {:ok, second} =
      Accounts.create_profile(%{
        account_id: account.id,
        name: "Partner"
      })

    {:ok, %{parent: parent, partner: second}}
  end

  test "create_space/2 creates owner membership and slug", %{parent: parent} do
    {:ok, space} =
      FamilySpace.create_space(parent.id, %{"name" => "Team Berg", "time_zone" => "Europe/Oslo"})

    assert space.slug == "team-berg"
    assert space.kind == :family
    assert [%Membership{role: :owner, profile_id: profile_id}] = space.memberships
    assert profile_id == parent.id
  end

  test "list_spaces/2 filters by kind", %{parent: parent, partner: partner} do
    {:ok, family} = FamilySpace.create_space(parent.id, %{"name" => "Familie"})
    {:ok, _} = FamilySpace.create_space(parent.id, %{"name" => "Bedrift", "kind" => "business"})
    {:ok, _} = FamilySpace.add_member(family.id, partner.id)

    families = FamilySpace.list_spaces(partner.id, kind: :family)
    assert Enum.map(families, & &1.id) == [family.id]
  end

  test "calendar event lifecycle", %{parent: parent, partner: partner} do
    {:ok, space} = FamilySpace.create_space(parent.id, %{"name" => "Familie"})
    {:ok, _} = FamilySpace.add_member(space.id, partner.id)

    starts_at = DateTime.utc_now() |> DateTime.truncate(:second)

    {:ok, event} =
      FamilySpace.create_event(space.id, partner.id, %{
        "title" => "Middag",
        "starts_at" => starts_at
      })

    assert event.space_id == space.id
    assert event.created_by_profile_id == partner.id

    {:ok, updated} =
      FamilySpace.update_event(space.id, event.id, partner.id, %{"title" => "Familie middag"})

    assert updated.title == "Familie middag"

    events = FamilySpace.list_events(space.id)
    assert [listed] = events
    assert listed.id == updated.id

    assert {:ok, _} = FamilySpace.delete_event(space.id, event.id, partner.id)
    assert [] == FamilySpace.list_events(space.id)
  end

  test "shopping list supports items", %{parent: parent, partner: partner} do
    {:ok, space} = FamilySpace.create_space(parent.id, %{"name" => "Familie"})
    {:ok, _} = FamilySpace.add_member(space.id, partner.id)

    {:ok, list} = FamilySpace.create_shopping_list(space.id, partner.id, %{name: "Handleliste"})
    assert list.created_by_profile_id == partner.id

    {:ok, item} =
      FamilySpace.add_shopping_item(space.id, list.id, partner.id, %{name: "Melk", quantity: "2"})

    assert %ShoppingItem{checked: false} = item

    {:ok, item} =
      FamilySpace.update_shopping_item(space.id, list.id, item.id, partner.id, %{checked: true})

    assert item.checked == true
    assert item.checked_by_profile_id == partner.id

    lists = FamilySpace.list_shopping_lists(space.id)
    assert [%{items: [%ShoppingItem{name: "Melk"}]}] = lists
  end

  test "todo list tracks completion", %{parent: parent, partner: partner} do
    {:ok, space} = FamilySpace.create_space(parent.id, %{"name" => "Familie"})
    {:ok, _} = FamilySpace.add_member(space.id, partner.id)

    {:ok, list} = FamilySpace.create_todo_list(space.id, parent.id, %{name: "Oppgaver"})

    {:ok, item} =
      FamilySpace.add_todo_item(space.id, list.id, parent.id, %{
        content: "Vaske gulvet",
        status: :pending,
        assignee_profile_id: partner.id
      })

    assert %TodoItem{status: :pending, assignee_profile_id: ^partner.id} = item

    {:ok, completed} =
      FamilySpace.update_todo_item(space.id, list.id, item.id, partner.id, %{status: :done})

    assert completed.status == :done
    assert completed.completed_by_profile_id == partner.id

    lists = FamilySpace.list_todo_lists(space.id)
    assert [%{items: [%TodoItem{status: :done}]}] = lists
  end
end
