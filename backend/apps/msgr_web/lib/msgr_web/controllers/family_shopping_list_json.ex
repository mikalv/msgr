defmodule MessngrWeb.FamilyShoppingListJSON do
  alias FamilySpace.{ShoppingItem, ShoppingList}
  alias Messngr.Accounts.Profile

  def index(%{lists: lists}) do
    %{data: Enum.map(lists, &list/1)}
  end

  def show(%{list: list}) do
    %{data: list(list)}
  end

  defp list(%ShoppingList{} = list) do
    %{
      id: list.id,
      space_id: list.space_id,
      name: list.name,
      status: list.status,
      created_by_profile_id: list.created_by_profile_id,
      created_by: maybe_profile(list.created_by),
      items: Enum.map(list.items, &item/1),
      inserted_at: render_datetime(list.inserted_at),
      updated_at: render_datetime(list.updated_at)
    }
  end

  defp item(%ShoppingItem{} = item) do
    %{
      id: item.id,
      list_id: item.list_id,
      name: item.name,
      quantity: item.quantity,
      checked: item.checked,
      added_by_profile_id: item.added_by_profile_id,
      checked_by_profile_id: item.checked_by_profile_id,
      added_by: maybe_profile(item.added_by),
      checked_by: maybe_profile(item.checked_by),
      inserted_at: render_datetime(item.inserted_at),
      updated_at: render_datetime(item.updated_at)
    }
  end

  defp maybe_profile(nil), do: nil
  defp maybe_profile(%Profile{} = profile), do: %{id: profile.id, name: profile.name, slug: profile.slug}

  defp render_datetime(nil), do: nil
  defp render_datetime(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
end
