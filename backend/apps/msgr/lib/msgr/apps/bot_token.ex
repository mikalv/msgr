defmodule Messngr.Apps.BotToken do
  @moduledoc """
  Represents a bot token for WebSocket-based bot connections.
  Tokens are stored as hashes — the raw token is only shown once at creation.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "bot_tokens" do
    field :token_hash, :string
    field :label, :string
    field :scopes, {:array, :string}, default: []
    field :last_used_at, :utc_datetime
    field :expires_at, :utc_datetime
    field :revoked_at, :utc_datetime
    field :inserted_at, :utc_datetime

    belongs_to :app_installation, Messngr.Apps.AppInstallation
  end

  @required_fields ~w(app_installation_id token_hash)a
  @optional_fields ~w(label scopes expires_at)a

  def changeset(token, attrs) do
    token
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> put_change_if_new(:inserted_at, DateTime.utc_now() |> DateTime.truncate(:second))
  end

  defp put_change_if_new(changeset, field, value) do
    if get_field(changeset, field) do
      changeset
    else
      put_change(changeset, field, value)
    end
  end

  @doc """
  Generates a secure random token prefixed with `mbt_`.
  Returns `{raw_token, hash}`.
  """
  def generate_token do
    raw = "mbt_" <> Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
    hash = :crypto.hash(:sha256, raw) |> Base.encode16(case: :lower)
    {raw, hash}
  end

  @doc """
  Hashes a raw token for lookup.
  """
  def hash_token(raw_token) do
    :crypto.hash(:sha256, raw_token) |> Base.encode16(case: :lower)
  end
end
