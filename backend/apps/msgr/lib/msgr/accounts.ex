defmodule Messngr.Accounts do
  @moduledoc """
  Accounts keeps logic for creating og hente globale kontoer og profiler.
  """

  import Ecto.Query

  alias Messngr.Accounts.{Account, Profile}
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
end
