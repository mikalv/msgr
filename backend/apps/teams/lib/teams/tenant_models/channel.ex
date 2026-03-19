defmodule Teams.TenantModels.Channel do
  @moduledoc """
  Tenant-scoped channel (replaces the old Room model).
  Supports channel, dm, and group_dm kinds.
  """

  use Teams.Schema
  import Ecto.Changeset
  import Ecto.Query

  schema "channels" do
    field :name, :string
    field :slug, :string
    field :icon, :string
    field :kind, :string, default: "channel"
    field :visibility, :string, default: "public"
    field :topic, :string

    belongs_to :creator, Teams.TenantModels.Profile, foreign_key: :created_by

    has_many :messages, Teams.TenantModels.Message, foreign_key: :channel_id
    has_many :memberships, Teams.TenantModels.ChannelMembership, foreign_key: :channel_id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(channel, attrs) do
    channel
    |> cast(attrs, [:name, :slug, :icon, :kind, :visibility, :topic, :created_by])
    |> validate_required([:name, :slug])
    |> validate_inclusion(:kind, ~w(channel dm group_dm))
    |> validate_inclusion(:visibility, ~w(public private))
    |> unique_constraint(:slug)
    |> generate_slug()
  end

  defp generate_slug(%{changes: %{slug: _}} = changeset), do: changeset

  defp generate_slug(%{changes: %{name: name}} = changeset) do
    slug =
      name
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9\-]/, "-")
      |> String.replace(~r/-+/, "-")
      |> String.trim("-")

    put_change(changeset, :slug, slug)
  end

  defp generate_slug(changeset), do: changeset

  # Query helpers

  def list(prefix) do
    Teams.Repo.all(__MODULE__, prefix: prefix)
  end

  def list_public(prefix) do
    from(c in __MODULE__, where: c.visibility == "public")
    |> Teams.Repo.all(prefix: prefix)
  end

  def get_by_id(prefix, id) do
    Teams.Repo.get(__MODULE__, id, prefix: prefix)
  end

  def get_by_slug(prefix, slug) do
    Teams.Repo.get_by(__MODULE__, [slug: slug], prefix: prefix)
  end

  def create(prefix, attrs) do
    cs = changeset(%__MODULE__{}, attrs)

    IO.puts("=== CHANNEL CREATE DEBUG ===")
    IO.puts("attrs: #{inspect(attrs)}")
    IO.puts("changeset valid: #{cs.valid?}")
    IO.puts("changeset changes: #{inspect(cs.changes)}")
    IO.puts("changeset errors: #{inspect(cs.errors)}")
    IO.puts("=== END DEBUG ===")

    Teams.Repo.insert(cs, prefix: prefix)
  end

  def update(prefix, %__MODULE__{} = channel, attrs) do
    channel
    |> changeset(attrs)
    |> Teams.Repo.update(prefix: prefix)
  end

  def delete(prefix, %__MODULE__{} = channel) do
    Teams.Repo.delete(channel, prefix: prefix)
  end
end
