defmodule Messngr.Accounts.Profile do
  @moduledoc """
  Profiles separate modes (Jobb, Privat, Familie) under én konto med egne
  preferanser og sikkerhetspolicyer.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "profiles" do
    field :name, :string
    field :slug, :string
    field :mode, Ecto.Enum, values: [:private, :work, :family], default: :private
    field :theme, :map, default: %{"primary" => "#4C6EF5", "accent" => "#EDF2FF"}
    field :notification_policy, :map, default: %{"allow_push" => true}
    field :security_policy, :map, default: %{"requires_pin" => false}

    belongs_to :account, Messngr.Accounts.Account

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(profile, attrs) do
    profile
    |> cast(attrs, [:name, :slug, :mode, :theme, :notification_policy, :security_policy, :account_id])
    |> validate_required([:name, :account_id])
    |> validate_length(:name, min: 2, max: 80)
    |> put_default_slug()
    |> unique_constraint(:slug, name: :profiles_account_id_slug_index)
  end

  defp put_default_slug(%{changes: %{slug: slug}} = changeset) when slug not in [nil, ""] do
    changeset
  end

  defp put_default_slug(%{changes: %{name: name}, data: %{id: id}} = changeset) when not is_nil(id) do
    slug =
      name
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]/, "-")
      |> String.replace(~r/-+/, "-")
      |> String.trim("-")

    change(changeset, slug: slug)
  end

  defp put_default_slug(%{changes: %{name: name}} = changeset) do
    slug =
      name
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]/, "-")
      |> String.replace(~r/-+/, "-")
      |> String.trim("-")

    change(changeset, slug: slug)
  end

  defp put_default_slug(changeset), do: changeset
end
