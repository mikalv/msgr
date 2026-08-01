defmodule Teams.TenantModels.MediaUpload do
  @moduledoc """
  Tenant-scoped media upload record.
  The actual file lives in MinIO; this tracks metadata and virus-scan state.
  """

  use Teams.Schema
  import Ecto.Changeset

  @scan_statuses ~w(awaiting_upload scanning clean infected error)a

  schema "media_uploads" do
    belongs_to :profile, Teams.TenantModels.Profile

    field :object_key, :string
    field :content_type, :string
    field :filename, :string
    field :size, :integer
    field :checksum, :string
    field :scan_status, Ecto.Enum, values: @scan_statuses, default: :awaiting_upload
    field :scanned_at, :utc_datetime
    field :threat_name, :string
    field :quarantine_key, :string

    timestamps(type: :utc_datetime)
  end

  def scan_statuses, do: @scan_statuses

  @doc false
  def changeset(upload, attrs) do
    upload
    |> cast(attrs, [
      :profile_id,
      :object_key,
      :content_type,
      :filename,
      :size,
      :checksum,
      :scan_status,
      :scanned_at,
      :threat_name,
      :quarantine_key
    ])
    |> validate_required([:object_key])
    |> validate_inclusion(:scan_status, @scan_statuses)
  end

  def create(prefix, attrs) do
    attrs = Map.put_new(attrs, :scan_status, :awaiting_upload)

    %__MODULE__{}
    |> changeset(attrs)
    |> Teams.Repo.insert(prefix: prefix)
  end

  def update(prefix, %__MODULE__{} = upload, attrs) do
    upload
    |> changeset(attrs)
    |> Teams.Repo.update(prefix: prefix)
  end

  def get_by_id(prefix, id) do
    Teams.Repo.get(__MODULE__, id, prefix: prefix)
  end

  @doc "Looks up a media upload by object_key within the tenant schema."
  def get_by_object_key(prefix, object_key) when is_binary(object_key) do
    import Ecto.Query

    from(u in __MODULE__, where: u.object_key == ^object_key)
    |> Teams.Repo.one(prefix: prefix)
  end

  def for_profile(prefix, profile_id) do
    import Ecto.Query

    from(u in __MODULE__, where: u.profile_id == ^profile_id, order_by: [desc: u.inserted_at])
    |> Teams.Repo.all(prefix: prefix)
  end

  @doc "True when the object may be downloaded by clients."
  def downloadable?(%__MODULE__{scan_status: :clean}), do: true
  def downloadable?(_), do: false
end
