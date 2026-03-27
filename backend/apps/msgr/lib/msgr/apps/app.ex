defmodule Messngr.Apps.App do
  @moduledoc """
  Represents an app in the global registry.
  Apps provide slash commands, bot users, and integrations.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "apps" do
    field :slug, :string
    field :name, :string
    field :description, :string
    field :icon_url, :string
    field :manifest, :map, default: %{}
    field :visibility, :string, default: "private"
    field :executor_type, :string
    field :webhook_url, :string
    field :webhook_secret, :string
    field :status, :string, default: "active"
    field :category, :string, default: "custom"
    field :featured, :boolean, default: false
    field :install_count, :integer, default: 0
    field :config_schema, :map, default: %{}
    field :channel_config_schema, :map, default: %{}
    field :required_scopes, {:array, :string}, default: []

    belongs_to :developer, Messngr.Accounts.Account, foreign_key: :developer_id
    belongs_to :bot_account, Messngr.Accounts.Account, foreign_key: :bot_account_id

    has_many :slash_commands, Messngr.Apps.SlashCommand
    has_many :installations, Messngr.Apps.AppInstallation

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(slug name executor_type)a
  @optional_fields ~w(description icon_url developer_id manifest visibility
                      webhook_url webhook_secret bot_account_id status
                      category featured install_count config_schema
                      channel_config_schema required_scopes)a

  def changeset(app, attrs) do
    app
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:executor_type, ~w(builtin webhook bot llm))
    |> validate_inclusion(:visibility, ~w(public private team-only))
    |> validate_inclusion(:status, ~w(active suspended deprecated))
    |> validate_format(:slug, ~r/^[a-z0-9\-]+$/,
      message: "must be lowercase alphanumeric with dashes"
    )
    |> validate_length(:slug, min: 2, max: 64)
    |> unique_constraint(:slug)
  end
end
