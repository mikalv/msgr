defmodule MessngrWeb.FamilyTodoListJSON do
  alias FamilySpace.{TodoItem, TodoList}
  alias Messngr.Accounts.Profile

  def index(%{lists: lists}) do
    %{data: Enum.map(lists, &list/1)}
  end

  def show(%{list: list}) do
    %{data: list(list)}
  end

  defp list(%TodoList{} = list) do
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
