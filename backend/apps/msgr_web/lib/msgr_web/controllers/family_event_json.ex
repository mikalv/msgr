defmodule MessngrWeb.FamilyEventJSON do
  alias FamilySpace.Event

  def index(%{events: events}) do
    %{data: Enum.map(events, &event/1)}
  end

  def show(%{event: event}) do
    %{data: event(event)}
  end

  defp event(%Event{} = event) do
    %{
      id: event.id,
      space_id: event.space_id,
      family_id: event.space_id,
      title: event.title,
      description: event.description,
      location: event.location,
      starts_at: render_datetime(event.starts_at),
      ends_at: render_datetime(event.ends_at),
      all_day: event.all_day,
      color: event.color,
      created_by_profile_id: event.created_by_profile_id,
      updated_by_profile_id: event.updated_by_profile_id,
      creator: maybe_profile(event.creator),
      updated_by: maybe_profile(event.updated_by),
      inserted_at: render_datetime(event.inserted_at),
      updated_at: render_datetime(event.updated_at)
    }
  end

  defp render_datetime(nil), do: nil
  defp render_datetime(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)

  defp maybe_profile(nil), do: nil
  defp maybe_profile(profile), do: %{id: profile.id, name: profile.name, slug: profile.slug}
end
