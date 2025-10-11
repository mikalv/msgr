defmodule MessngrWeb.FamilyTodoItemJSON do
  alias FamilySpace.TodoItem
  alias Messngr.Accounts.Profile

  def index(%{list: list}) do
    %{data: Enum.map(list.items, &item/1)}
  end

  def show(%{item: item}) do
    %{data: item(item)}
  end

  defp item(%TodoItem{} = item) do
    %{
      id: item.id,
      list_id: item.list_id,
      content: item.content,
      status: item.status,
      due_at: render_datetime(item.due_at),
      created_by_profile_id: item.created_by_profile_id,
      assignee_profile_id: item.assignee_profile_id,
      completed_by_profile_id: item.completed_by_profile_id,
      created_by: maybe_profile(item.created_by),
      assignee: maybe_profile(item.assignee),
      completed_by: maybe_profile(item.completed_by),
      inserted_at: render_datetime(item.inserted_at),
      updated_at: render_datetime(item.updated_at)
    }
  end

  defp maybe_profile(nil), do: nil
  defp maybe_profile(%Profile{} = profile), do: %{id: profile.id, name: profile.name, slug: profile.slug}

  defp render_datetime(nil), do: nil
  defp render_datetime(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
end
