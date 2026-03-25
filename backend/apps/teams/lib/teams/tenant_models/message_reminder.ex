defmodule Teams.TenantModels.MessageReminder do
  use Teams.Schema
  import Ecto.Changeset
  import Ecto.Query

  schema "message_reminders" do
    field :channel_id, :binary_id
    field :remind_at, :utc_datetime
    field :delivered, :boolean, default: false
    field :message_preview, :string

    belongs_to :message, Teams.TenantModels.Message
    belongs_to :profile, Teams.TenantModels.Profile

    timestamps(type: :utc_datetime)
  end

  def changeset(reminder, attrs) do
    reminder
    |> cast(attrs, [:message_id, :channel_id, :profile_id, :remind_at, :delivered, :message_preview])
    |> validate_required([:message_id, :channel_id, :profile_id, :remind_at])
  end

  def create(prefix, attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Teams.Repo.insert(prefix: prefix)
  end

  @doc "Find all due reminders across ALL tenants (called by scheduler)."
  def find_due(prefix) do
    now = DateTime.utc_now()

    from(r in __MODULE__,
      where: r.delivered == false and r.remind_at <= ^now,
      preload: [:profile, :message]
    )
    |> Teams.Repo.all(prefix: prefix)
  end

  def mark_delivered(prefix, id) do
    from(r in __MODULE__, where: r.id == ^id)
    |> Teams.Repo.update_all([set: [delivered: true]], prefix: prefix)
  end

  def list_for_profile(prefix, profile_id) do
    from(r in __MODULE__,
      where: r.profile_id == ^profile_id and r.delivered == false,
      order_by: [asc: r.remind_at]
    )
    |> Teams.Repo.all(prefix: prefix)
  end
end
