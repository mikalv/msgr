defmodule Messngr.FamilyTest do
  use Messngr.DataCase

  alias Messngr.{Accounts, Family}

  setup do
    {:ok, account_parent} = Accounts.create_account(%{"display_name" => "Forelder"})
    {:ok, account_child} = Accounts.create_account(%{"display_name" => "Barn"})

    parent = List.first(account_parent.profiles)
    child = List.first(account_child.profiles)

    {:ok, %{parent: parent, child: child}}
  end

  describe "families" do
    test "create_family/2 creates owner membership and slug", %{parent: parent} do
      {:ok, family} = Family.create_family(parent.id, %{"name" => "Team Berg", "time_zone" => "Europe/Oslo"})

      assert family.name == "Team Berg"
      assert family.slug == "team-berg"
      assert Enum.any?(family.memberships, &(&1.profile_id == parent.id and &1.role == :owner))

      families = Family.list_families(parent.id)
      assert Enum.map(families, & &1.id) == [family.id]
    end

    test "create_family/2 generates unique slug for duplicates", %{parent: parent} do
      {:ok, family_a} = Family.create_family(parent.id, %{"name" => "Familien Hansen"})
      {:ok, family_b} = Family.create_family(parent.id, %{"name" => "Familien Hansen"})

      refute family_a.slug == family_b.slug
    end

    test "add_member/3 adds a member", %{parent: parent, child: child} do
      {:ok, family} = Family.create_family(parent.id, %{"name" => "Familie"})
      assert {:ok, _} = Family.add_member(family.id, child.id)

      families_for_child = Family.list_families(child.id)
      assert [%{id: ^family.id}] = families_for_child
    end
  end

  describe "events" do
    setup %{parent: parent, child: child} do
      {:ok, family} = Family.create_family(parent.id, %{"name" => "Familiekalender"})
      {:ok, _} = Family.add_member(family.id, child.id)

      {:ok, %{family: family}}
    end

    test "create_event/3 stores event and list filters", %{parent: parent, family: family} do
      starts_at = DateTime.utc_now() |> DateTime.truncate(:second)
      later = DateTime.add(starts_at, 3600, :second)
      much_later = DateTime.add(starts_at, 86_400, :second)

      {:ok, event} =
        Family.create_event(family.id, parent.id, %{
          "title" => "Felles middag",
          "starts_at" => starts_at,
          "ends_at" => later,
          "color" => "#ff8800"
        })

      {:ok, _} =
        Family.create_event(family.id, parent.id, %{
          "title" => "Helgetur",
          "starts_at" => much_later,
          "ends_at" => DateTime.add(much_later, 7200, :second)
        })

      events = Family.list_events(family.id)
      assert length(events) == 2

      upcoming = Family.list_events(family.id, from: DateTime.add(starts_at, 7200, :second))
      assert Enum.map(upcoming, & &1.title) == ["Helgetur"]

      assert event.created_by_profile_id == parent.id
      assert event.updated_by_profile_id == parent.id
    end

    test "update_event/4 updates and tracks updater", %{child: child, family: family, parent: parent} do
      starts_at = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, event} =
        Family.create_event(family.id, parent.id, %{
          "title" => "Foreldremøte",
          "starts_at" => starts_at
        })

      {:ok, updated} = Family.update_event(family.id, event.id, child.id, %{"title" => "Foreldremøte på Teams"})
      assert updated.title == "Foreldremøte på Teams"
      assert updated.updated_by_profile_id == child.id
    end

    test "delete_event/3 removes the event", %{family: family, parent: parent} do
      starts_at = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, event} =
        Family.create_event(family.id, parent.id, %{
          "title" => "Trening",
          "starts_at" => starts_at
        })

      assert {:ok, _} = Family.delete_event(family.id, event.id, parent.id)
      assert_raise Ecto.NoResultsError, fn -> Family.get_event!(family.id, event.id) end
    end
  end
end
