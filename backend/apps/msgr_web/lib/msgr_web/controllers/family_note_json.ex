defmodule MessngrWeb.FamilyNoteJSON do
  alias FamilySpace.Note

  def index(%{notes: notes}) do
    %{data: Enum.map(notes, &note/1)}
  end

  def show(%{note: note}) do
    %{data: note(note)}
  end

  defp note(%Note{} = note) do
    %{
      id: note.id,
      space_id: note.space_id,
      family_id: note.space_id,
      title: note.title,
      body: note.body,
      color: note.color,
      pinned: note.pinned,
      created_by_profile_id: note.created_by_profile_id,
      updated_by_profile_id: note.updated_by_profile_id,
      creator: maybe_profile(note.created_by),
      updated_by: maybe_profile(note.updated_by),
      inserted_at: render_datetime(note.inserted_at),
      updated_at: render_datetime(note.updated_at)
    }
  end

  defp render_datetime(nil), do: nil
  defp render_datetime(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)

  defp maybe_profile(nil), do: nil
  defp maybe_profile(profile), do: %{id: profile.id, name: profile.name, slug: profile.slug}
end
