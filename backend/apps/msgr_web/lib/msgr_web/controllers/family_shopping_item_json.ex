defmodule MessngrWeb.FamilyShoppingItemJSON do
  alias FamilySpace.ShoppingItem
  alias Messngr.Accounts.Profile

  def index(%{list: list}) do
    %{data: Enum.map(list.items, &item/1)}
  end

  def show(%{item: item}) do
    %{data: item(item)}
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
