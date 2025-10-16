defmodule Messngr.Accounts.ProfileBackupCode do
  @moduledoc """
  Backup codes allow a profile to recover encrypted key material when their
  devices are lost.

  Codes are stored as salted hashes. Callers should persist the plaintext code
  client-side at generation time.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Messngr.Accounts.Profile

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "profile_backup_codes" do
    field :code_hash, :binary
    field :salt, :binary
    field :label, :string
    field :generation, :integer, default: 1
    field :used_at, :utc_datetime

    belongs_to :profile, Profile

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(backup_code, attrs) do
    backup_code
    |> cast(attrs, [:profile_id, :code_hash, :salt, :label, :generation, :used_at])
    |> validate_required([:profile_id, :code_hash, :salt, :generation])
    |> validate_number(:generation, greater_than: 0)
    |> foreign_key_constraint(:profile_id)
  end
end
