defmodule Messngr.Auth.Challenge do
  @moduledoc """
  Stores OTP challenges for passwordless authentication.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "auth_challenges" do
    field :channel, Ecto.Enum, values: [:email, :phone]
    field :target, :string
    field :code_hash, :string
    field :issued_for, :string
    field :expires_at, :utc_datetime
    field :consumed_at, :utc_datetime

    belongs_to :identity, Messngr.Accounts.Identity

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(challenge, attrs) do
    challenge
    |> cast(attrs, [:channel, :target, :code_hash, :expires_at, :consumed_at, :identity_id, :issued_for])
    |> validate_required([:channel, :target, :code_hash, :expires_at])
    |> validate_length(:target, min: 4)
    |> unique_constraint(:active_challenge,
      name: :auth_challenges_identity_id_consumed_at_index,
      message: "an active challenge already exists"
    )
  end
end

