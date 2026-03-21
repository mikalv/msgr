defmodule Messngr.Apps.SlashCommand do
  @moduledoc """
  Represents a slash command registered by an app.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "slash_commands" do
    field :name, :string
    field :description, :string
    field :args_schema, :map
    field :permissions, :string, default: "member"

    belongs_to :app, Messngr.Apps.App
  end

  @required_fields ~w(app_id name)a
  @optional_fields ~w(description args_schema permissions)a

  def changeset(command, attrs) do
    command
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:permissions, ~w(owner admin member))
    |> validate_format(:name, ~r/^[a-z0-9\-_]+$/,
      message: "must be lowercase alphanumeric with dashes or underscores"
    )
    |> unique_constraint([:app_id, :name])
  end
end
