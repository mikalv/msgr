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
    has_many :devices, Messngr.Accounts.Device

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(account, attrs) do
    account
    |> cast(attrs, [:email, :phone_number, :display_name, :handle, :locale, :time_zone])
    |> put_default_display_name()
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

  defp put_default_display_name(%{changes: %{display_name: display_name}} = changeset)
       when is_binary(display_name) and display_name != "" do
    change(changeset, display_name: String.trim(display_name))
  end

  defp put_default_display_name(%{changes: changes} = changeset) do
    fallback =
      cond do
        email = Map.get(changes, :email) -> derive_from_email(email)
        phone = Map.get(changes, :phone_number) -> derive_from_phone(phone)
        true -> nil
      end

    if is_binary(fallback) and fallback != "" do
      change(changeset, display_name: fallback)
    else
      changeset
    end
  end

  defp put_default_display_name(changeset), do: changeset

  defp derive_from_email(email) when is_binary(email) do
    email
    |> String.split("@")
    |> hd()
    |> String.replace(~r/[^\w]/, " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp derive_from_email(_), do: nil

  defp derive_from_phone(phone) when is_binary(phone) do
    suffix = phone |> String.trim_leading("+") |> String.slice(-4, 4)
    "Bruker #{suffix}"
  end

  defp derive_from_phone(_), do: nil
end
