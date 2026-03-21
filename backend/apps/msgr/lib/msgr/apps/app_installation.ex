defmodule Messngr.Apps.AppInstallation do
  @moduledoc """
  Represents an app installed in a specific team.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "app_installations" do
    field :config, :map, default: %{}
    field :secrets_encrypted, :binary
    field :enabled_scopes, {:array, :string}, default: []
    field :enabled_channels, {:array, :binary_id}, default: []
    field :status, :string, default: "active"

    belongs_to :app, Messngr.Apps.App
    belongs_to :team, Messngr.Teams.Team, foreign_key: :team_id
    belongs_to :installer, Messngr.Accounts.Account, foreign_key: :installed_by

    has_many :bot_tokens, Messngr.Apps.BotToken

    field :installed_at, :utc_datetime
    field :updated_at, :utc_datetime
  end

  @required_fields ~w(app_id team_id)a
  @optional_fields ~w(installed_by config secrets_encrypted enabled_scopes
                      enabled_channels status installed_at updated_at)a

  def changeset(installation, attrs) do
    installation
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:status, ~w(active disabled))
    |> unique_constraint([:app_id, :team_id])
    |> put_timestamps()
  end

  defp put_timestamps(changeset) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    changeset
    |> put_change_if_new(:installed_at, now)
    |> put_change(:updated_at, now)
  end

  defp put_change_if_new(changeset, field, value) do
    if get_field(changeset, field) do
      changeset
    else
      put_change(changeset, field, value)
    end
  end
end
