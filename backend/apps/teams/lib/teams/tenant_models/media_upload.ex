defmodule Teams.TenantModels.MediaUpload do
  @moduledoc """
  Tenant-scoped media upload record.
  The actual file lives in MinIO; this tracks metadata.
  """

  use Teams.Schema
  import Ecto.Changeset

  schema "media_uploads" do
    belongs_to :profile, Teams.TenantModels.Profile

    field :object_key, :string
    field :content_type, :string
    field :filename, :string
    field :size, :integer
    field :checksum, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(upload, attrs) do
    upload
    |> cast(attrs, [:profile_id, :object_key, :content_type, :filename, :size, :checksum])
    |> validate_required([:object_key])
  end

  def create(prefix, attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> Teams.Repo.insert(prefix: prefix)
  end

  def get_by_id(prefix, id) do
    Teams.Repo.get(__MODULE__, id, prefix: prefix)
  end

  def for_profile(prefix, profile_id) do
    import Ecto.Query

    from(u in __MODULE__, where: u.profile_id == ^profile_id, order_by: [desc: u.inserted_at])
    |> Teams.Repo.all(prefix: prefix)
  end
end
