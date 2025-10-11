defmodule Messngr.Accounts do
  @moduledoc """
  Accounts keeps logic for creating og hente globale kontoer og profiler.
  """

  import Ecto.Query

  alias Messngr.Accounts.{Account, Identity, Profile}
  alias Messngr.Repo

  @spec list_accounts() :: [Account.t()]
  def list_accounts do
    Repo.all(from a in Account, preload: [:profiles])
  end

  @spec get_account!(Ecto.UUID.t()) :: Account.t()
  def get_account!(id), do: Repo.get!(Account, id) |> Repo.preload(:profiles)

  @spec create_account(map()) :: {:ok, Account.t()} | {:error, Ecto.Changeset.t()}
  def create_account(attrs) do
    Repo.transaction(fn ->
      with {:ok, account} <- do_create_account(attrs),
           {:ok, profile} <- ensure_primary_profile(account, attrs) do
        %{account | profiles: [profile]}
      else
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> case do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end

  defp do_create_account(attrs) do
    %Account{}
    |> Account.changeset(attrs)
    |> Repo.insert()
  end

  defp ensure_primary_profile(account, attrs) do
    profile_attrs =
      attrs
      |> fetch_profile_attrs()
      |> Map.merge(%{"name" => fetch_profile_name(attrs), "account_id" => account.id})

    create_profile(profile_attrs)
  end

  defp fetch_profile_attrs(attrs) do
    cond do
      profile = Map.get(attrs, "profile") -> profile
      profile = Map.get(attrs, :profile) -> profile
      true -> %{}
    end
  end

  defp fetch_profile_name(attrs) do
    attrs |> Map.get("profile_name") || Map.get(attrs, :profile_name) || "Privat"
  end

  @spec create_profile(map()) :: {:ok, Profile.t()} | {:error, Ecto.Changeset.t()}
  def create_profile(attrs) do
    %Profile{}
    |> Profile.changeset(attrs)
    |> Repo.insert()
  end

  @spec list_profiles(Ecto.UUID.t()) :: [Profile.t()]
  def list_profiles(account_id) do
    Repo.all(from p in Profile, where: p.account_id == ^account_id)
  end

  @spec get_profile!(Ecto.UUID.t()) :: Profile.t()
  def get_profile!(id), do: Repo.get!(Profile, id)

  @doc """
  Fetches an identity for the given channel (email/phone) or returns nil.
  """
  @spec get_identity_by_channel(:email | :phone, String.t()) :: Identity.t() | nil
  def get_identity_by_channel(channel, target) when channel in [:email, :phone] do
    Repo.get_by(Identity, kind: channel, value: normalize_target(channel, target))
    |> maybe_preload_account()
  end

  @doc """
  Ensures that an identity exists for the provided attributes, creating the owning
  account as needed.
  """
  @spec ensure_identity(map()) :: {:ok, Identity.t()} | {:error, term()}
  def ensure_identity(%{kind: :oidc} = attrs) do
    Repo.transaction(fn ->
      case Repo.get_by(Identity,
             kind: :oidc,
             provider: Map.get(attrs, :provider) || Map.get(attrs, "provider"),
             subject: Map.get(attrs, :subject) || Map.get(attrs, "subject")
           ) do
        nil ->
          with {:ok, account} <- ensure_account(attrs),
               {:ok, identity} <- insert_identity(account, attrs) do
            maybe_preload_account(identity)
          else
            {:error, reason} -> Repo.rollback(reason)
          end

        identity ->
          maybe_preload_account(identity)
      end
    end)
  end

  def ensure_identity(%{kind: kind} = attrs) when kind in [:email, :phone] do
    Repo.transaction(fn ->
      target = Map.get(attrs, :value) || Map.get(attrs, "value")
      normalized = normalize_target(kind, target)

      case Repo.get_by(Identity, kind: kind, value: normalized) do
        nil ->
          with {:ok, account} <- ensure_account(Map.put(attrs, :value, normalized)),
               {:ok, identity} <- insert_identity(account, Map.put(attrs, :value, normalized)) do
            maybe_preload_account(identity)
          else
            {:error, reason} -> Repo.rollback(reason)
          end

        identity ->
          maybe_preload_account(identity)
      end
    end)
  end

  @doc """
  Marks an identity as verified and updates metadata.
  """
  @spec verify_identity(Identity.t(), map()) :: {:ok, Identity.t()} | {:error, term()}
  def verify_identity(%Identity{} = identity, attrs) do
    attrs =
      attrs
      |> Map.new()
      |> Map.put_new(:verified_at, DateTime.utc_now())

    identity
    |> Identity.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, identity} -> {:ok, maybe_preload_account(identity)}
      other -> other
    end
  end

  @doc false
  def touch_identity(%Identity{} = identity, attrs) do
    identity
    |> Identity.changeset(attrs)
    |> Repo.update()
  end

  defp ensure_account(attrs) do
    default_attrs =
      attrs
      |> account_attrs_from_identity()
      |> Enum.into(%{})

    create_account(default_attrs)
  end

  defp insert_identity(account, attrs) do
    identity_attrs =
      attrs
      |> Map.new()
      |> Map.put(:account_id, account.id)
      |> Map.put_new(:kind, Map.get(attrs, :kind) || Map.get(attrs, "kind"))
      |> Map.put_new(:value, Map.get(attrs, :value) || Map.get(attrs, :email) || Map.get(attrs, :phone_number))
      |> Map.put_new(:provider, Map.get(attrs, :provider) || Map.get(attrs, "provider"))
      |> Map.put_new(:subject, Map.get(attrs, :subject) || Map.get(attrs, "subject"))

    %Identity{}
    |> Identity.changeset(identity_attrs)
    |> Repo.insert()
  end

  defp maybe_preload_account(nil), do: nil

  defp maybe_preload_account(identity) do
    Repo.preload(identity, :account)
  end

  defp normalize_target(_kind, nil), do: nil
  defp normalize_target(:email, target), do: target |> String.trim() |> String.downcase()
  defp normalize_target(:phone, target), do: target |> String.replace(~r/\s+/, "")

  defp account_attrs_from_identity(%{kind: :email} = attrs) do
    value = Map.get(attrs, :value) || Map.get(attrs, :email)

    [
      {:email, value},
      {:display_name, Map.get(attrs, :display_name) || derive_email_name(value)}
    ]
  end

  defp account_attrs_from_identity(%{kind: :phone} = attrs) do
    value = Map.get(attrs, :value) || Map.get(attrs, :phone_number)

    [
      {:phone_number, value},
      {:display_name, Map.get(attrs, :display_name) || derive_phone_name(value)}
    ]
  end

  defp account_attrs_from_identity(%{kind: :oidc} = attrs) do
    [
      {:display_name, Map.get(attrs, :display_name) || "Gjennom OIDC"},
      {:email, Map.get(attrs, :email)}
    ]
  end

  defp derive_email_name(nil), do: "Ny bruker"

  defp derive_email_name(email) do
    email
    |> String.split("@")
    |> hd()
    |> String.replace(~r/[^\w]/, " ")
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
    |> case do
      "" -> "Ny bruker"
      value -> value
    end
  end

  defp derive_phone_name(nil), do: "Ny bruker"

  defp derive_phone_name(number) do
    suffix = number |> String.trim_leading("+") |> String.slice(-4, 4)
    "Bruker #{suffix}"
  end
end
