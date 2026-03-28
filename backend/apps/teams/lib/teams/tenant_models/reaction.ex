defmodule Teams.TenantModels.Reaction do
  @moduledoc """
  Tenant-scoped emoji reaction on a message.
  Composite PK: (message_id, profile_id, emoji).
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key false
  @foreign_key_type :binary_id

  schema "reactions" do
    belongs_to :message, Teams.TenantModels.Message, primary_key: true
    belongs_to :profile, Teams.TenantModels.Profile, primary_key: true

    field :emoji, :string, primary_key: true
  end

  @doc false
  def changeset(reaction, attrs) do
    reaction
    |> cast(attrs, [:message_id, :profile_id, :emoji])
    |> validate_required([:message_id, :profile_id, :emoji])
    |> unique_constraint([:message_id, :profile_id, :emoji], name: :reactions_pkey)
  end

  def for_message(prefix, message_id) do
    from(r in __MODULE__,
      where: r.message_id == ^message_id,
      preload: [:profile]
    )
    |> Teams.Repo.all(prefix: prefix)
  end

  def toggle(prefix, %{message_id: message_id, profile_id: profile_id, emoji: emoji} = attrs) do
    case Teams.Repo.get_by(
           __MODULE__,
           [message_id: message_id, profile_id: profile_id, emoji: emoji],
           prefix: prefix
         ) do
      nil ->
        %__MODULE__{}
        |> changeset(to_map(attrs))
        |> Teams.Repo.insert(prefix: prefix)

      existing ->
        Teams.Repo.delete(existing, prefix: prefix)
    end
  end

  defp to_map(%{__struct__: _} = s), do: Map.from_struct(s)
  defp to_map(m) when is_map(m), do: m
end
