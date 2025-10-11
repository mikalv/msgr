defmodule Messngr.Accounts do
  @moduledoc """
  Accounts keeps logic for creating og hente globale kontoer og profiler.
  """

  import Ecto.Query

  alias Messngr.Accounts.{Account, Contact, Identity, Profile}
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
  Imports a batch of contacts for the given account. Existing contacts are
  oppdatert basert på e-post eller telefonnummer.
  """
  @spec import_contacts(Ecto.UUID.t(), [map()], keyword()) ::
          {:ok, [Contact.t()]} | {:error, term()}
  def import_contacts(account_id, contacts_attrs, opts \\ []) when is_list(contacts_attrs) do
    profile_id = Keyword.get(opts, :profile_id)

    Repo.transaction(fn ->
      contacts_attrs
      |> Enum.reduce_while([], fn attrs, acc ->
        normalized = normalize_contact_attrs(account_id, profile_id, attrs)

        case upsert_contact(normalized) do
          {:ok, contact} -> {:cont, [contact | acc]}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)
      |> case do
        {:error, reason} -> Repo.rollback(reason)
        contacts -> Enum.reverse(contacts)
      end
    end)
    |> case do
      {:ok, contacts} -> {:ok, contacts}
      {:error, reason} -> {:error, reason}
    end
  end

  def import_contacts(_account_id, _contacts_attrs, _opts), do: {:error, :invalid_contacts}

  @doc """
  Looks up kjente kontakter basert på e-post eller telefonnummer.
  """
  @spec lookup_known_contacts([map()]) :: {:ok, [map()]}
  def lookup_known_contacts(targets) when is_list(targets) do
    results =
      Enum.map(targets, fn attrs ->
        normalized = normalize_lookup_attrs(attrs)
        match = find_identity_match(normalized)

        %{query: normalized, match: match}
      end)

    {:ok, results}
  end

  def lookup_known_contacts(_targets), do: {:ok, []}

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

  defp normalize_contact_attrs(account_id, profile_id, attrs) do
    attrs = Map.new(attrs)

    email =
      attrs
      |> Map.get("email")
      |> Kernel.||(Map.get(attrs, :email))

    phone =
      attrs
      |> Map.get("phone_number")
      |> Kernel.||(Map.get(attrs, :phone_number))
      |> Kernel.||(Map.get(attrs, :phone))

    name =
      attrs
      |> Map.get("name")
      |> Kernel.||(Map.get(attrs, :name))
      |> Kernel.||(email)
      |> Kernel.||(phone)
      |> Kernel.||("Kontakt")
      |> to_string()
      |> String.trim()
      |> case do
        "" -> "Kontakt"
        value -> value
      end

    labels =
      attrs
      |> Map.get("labels")
      |> Kernel.||(Map.get(attrs, :labels))
      |> normalize_labels()

    metadata =
      attrs
      |> Map.get("metadata")
      |> Kernel.||(Map.get(attrs, :metadata))
      |> normalize_metadata()

    base = %{
      account_id: account_id,
      name: name,
      email: normalize_target(:email, email),
      phone_number: normalize_phone(phone),
      labels: labels,
      metadata: metadata
    }

    case profile_id do
      nil -> base
      value -> Map.put(base, :profile_id, value)
    end
  end

  defp normalize_lookup_attrs(attrs) do
    attrs = Map.new(attrs)

    email = attrs |> Map.get("email") |> Kernel.||(Map.get(attrs, :email))
    phone =
      attrs
      |> Map.get("phone_number")
      |> Kernel.||(Map.get(attrs, :phone_number))
      |> Kernel.||(Map.get(attrs, :phone))

    %{
      email: normalize_target(:email, email),
      phone_number: normalize_phone(phone)
    }
  end

  defp normalize_labels(nil), do: []
  defp normalize_labels(labels) when is_list(labels) do
    labels
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp normalize_labels(_), do: []

  defp normalize_metadata(nil), do: %{}
  defp normalize_metadata(map) when is_map(map), do: map
  defp normalize_metadata(_), do: %{}

  defp normalize_phone(nil), do: nil
  defp normalize_phone(phone), do: phone |> String.replace(~r/\D+/, "") |> empty_to_nil()

  defp empty_to_nil(""), do: nil
  defp empty_to_nil(value), do: value

  defp upsert_contact(%{account_id: account_id} = attrs) do
    case find_existing_contact(account_id, attrs) do
      %Contact{} = contact ->
        contact
        |> Contact.changeset(attrs)
        |> Repo.update()

      nil ->
        %Contact{}
        |> Contact.changeset(attrs)
        |> Repo.insert()
    end
  end

  defp upsert_contact(_), do: {:error, :invalid_contact}

  defp find_existing_contact(account_id, %{email: email}) when not is_nil(email) do
    Repo.get_by(Contact, account_id: account_id, email: email)
  end

  defp find_existing_contact(account_id, %{phone_number: phone}) when not is_nil(phone) do
    Repo.get_by(Contact, account_id: account_id, phone_number: phone)
  end

  defp find_existing_contact(_account_id, _attrs), do: nil

  defp find_identity_match(%{email: email} = normalized) when not is_nil(email) do
    normalized
    |> Map.put(:identity_kind, :email)
    |> do_find_identity(:email, email)
  end

  defp find_identity_match(%{phone_number: phone} = normalized) when not is_nil(phone) do
    normalized
    |> Map.put(:identity_kind, :phone)
    |> do_find_identity(:phone, phone)
  end

  defp find_identity_match(_), do: nil

  defp do_find_identity(normalized, kind, value) do
    case get_identity_by_channel(kind, value) do
      %Identity{} = identity ->
        account = Repo.preload(identity.account, :profiles)
        profile = List.first(account.profiles)

        %{
          account_id: account.id,
          account_name: account.display_name,
          identity_kind: identity.kind,
          identity_value: identity.value,
          profile:
            if(profile, do: %{id: profile.id, name: profile.name, mode: profile.mode}, else: nil)
        }

      _ ->
        nil
    end
  end

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
