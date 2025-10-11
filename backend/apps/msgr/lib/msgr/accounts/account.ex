defmodule Messngr.Accounts.Account do
  @moduledoc """
  Represents the top-level identity in the system. An account can own multiple
  profiles (Jobb, Privat, Familie) that provide context specific settings.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "accounts" do
    field :email, :string
    field :phone_number, :string
    field :display_name, :string
    field :handle, :string
    field :locale, :string, default: "nb_NO"
    field :time_zone, :string, default: "Europe/Oslo"

    has_many :profiles, Messngr.Accounts.Profile

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(account, attrs) do
    account
    |> cast(attrs, [:email, :phone_number, :display_name, :handle, :locale, :time_zone])
    |> validate_required([:display_name])
    |> validate_length(:display_name, min: 2, max: 120)
    |> validate_format(:email, ~r/@/, message: "must look like an email address")
    |> unique_constraint(:email)
    |> unique_constraint(:handle)
    |> unique_constraint(:phone_number)
    |> put_default_handle()
  end

  defp put_default_handle(%{changes: %{handle: handle}} = changeset) when handle != nil do
    changeset
  end

  defp put_default_handle(%{changes: %{display_name: display_name}} = changeset) do
    handle =
      display_name
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]/, "")
      |> String.slice(0, 24)

    change(changeset, handle: handle)
  end

  defp put_default_handle(changeset), do: changeset
end
