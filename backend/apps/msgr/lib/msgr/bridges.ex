defmodule Messngr.Bridges do
  @moduledoc """
  Persists bridge identity state (sessions, capabilities, contacts, channels).

  Bridge daemons report their current capabilities and roster/channel snapshots
  when a user links an external account. The data lives in Postgres so Msgr can
  reason about available features, drive degraded-mode UX, and reconcile remote
  membership lists.
  """

  import Ecto.Query, warn: false

  alias Ecto.Changeset
  alias Messngr.Accounts.Account
  alias Messngr.Accounts.Contact, as: MsgrContact
  alias Messngr.Bridges.{BridgeAccount, Channel, Contact, ContactProfile, ContactProfileKey, ProfileLink}
  alias Messngr.ShareLinks
  alias Messngr.Repo

  @default_instance "primary"

  @type service :: atom() | String.t()
  @type account_id :: binary()
  @type sync_attrs :: map()

  @doc """
  Fetches a bridge account for the given service if one has been synced.
  """
  @spec get_account(account_id(), service(), keyword()) :: BridgeAccount.t() | nil
  def get_account(account_id, service, opts \\ []) do
    service = normalise_service(service)

    instance =
      opts
      |> Keyword.get(:instance)
      |> normalise_instance_default()

    case instance do
      {:ok, instance_value} ->
        Repo.get_by(BridgeAccount, account_id: account_id, service: service, instance: instance_value)
        |> maybe_preload()

      {:error, _reason} ->
        nil
    end
  end

  @doc """
  Lists all bridge accounts currently linked to the supplied Msgr account.
  """
  @spec list_accounts(account_id()) :: [BridgeAccount.t()]
  def list_accounts(account_id) when is_binary(account_id) do
    Repo.all(from account in BridgeAccount, where: account.account_id == ^account_id)
  end

  def list_accounts(_account_id), do: []

  @doc """
  Returns the default bridge instance identifier used by single-tenant connectors.
  """
  @spec default_instance() :: String.t()
  def default_instance, do: @default_instance

  @doc """
  Creates a share link tied to a bridge account so binary payloads can be
  shared with low-capability networks (e.g. IRC).
  """
  @spec create_share_link(binary(), ShareLinks.ShareLink.kind() | atom() | String.t(), map()) ::
          {:ok, ShareLinks.ShareLink.t()} | {:error, term()}
  def create_share_link(bridge_account_id, kind, attrs \\ %{}) do
    case Repo.get(BridgeAccount, bridge_account_id) do
      nil -> {:error, :unknown_bridge_account}
      %BridgeAccount{} = bridge_account -> ShareLinks.create_bridge_link(bridge_account, kind, attrs)
    end
  end

  @doc """
  Unlinks a previously connected bridge account and cascades associated state.
  Returns `{:error, :not_found}` when the service has not been linked.
  """
  @spec unlink_account(account_id() | Account.t(), service(), keyword()) ::
          {:ok, BridgeAccount.t()} | {:error, term()}
  def unlink_account(account, service, opts \\ [])

  def unlink_account(%Account{id: account_id}, service, opts), do: unlink_account(account_id, service, opts)

  def unlink_account(account_id, service, opts) when is_binary(account_id) and is_list(opts) do
    service = normalise_service(service)

    with {:ok, instance} <- normalise_instance_default(Keyword.get(opts, :instance)) do
      case Repo.get_by(BridgeAccount, account_id: account_id, service: service, instance: instance) do
        nil -> {:error, :not_found}
        %BridgeAccount{} = account -> Repo.delete(account)
      end
    end
  end

  def unlink_account(_account_id, _service, _opts), do: {:error, :invalid_account}

  @doc """
  Fetches an active share link by token, returning an error if it has expired or
  exhausted its view limit.
  """
  @spec fetch_share_link(String.t(), keyword()) :: {:ok, ShareLinks.ShareLink.t()} | {:error, term()}
  def fetch_share_link(token, opts \\ []) do
    ShareLinks.fetch_active(token, opts)
  end

  defdelegate share_link_public_url(link), to: ShareLinks, as: :public_url
  defdelegate share_link_msgr_url(link), to: ShareLinks, as: :msgr_url
  defdelegate share_link_capabilities(kind), to: ShareLinks, as: :default_capabilities
  defdelegate share_link_remaining_views(link), to: ShareLinks, as: :remaining_views

  @doc """
  Synchronises a bridge identity, replacing contacts/channels with the snapshot provided.
  """
  @spec sync_linked_identity(account_id(), service(), sync_attrs(), keyword()) ::
          {:ok, BridgeAccount.t()} | {:error, Changeset.t() | term()}
  def sync_linked_identity(account_id, service, attrs \\ %{}, opts \\ []) do
    service = normalise_service(service)

    with {:ok, instance} <- resolve_instance(attrs, opts) do
      timestamp = DateTime.utc_now() |> DateTime.truncate(:second)

      Repo.transaction(fn ->
        params = %{
          account_id: account_id,
          service: service,
          instance: instance,
          external_id: safe_string(fetch_attr(attrs, ["external_id", :external_id])),
          display_name: safe_string(fetch_attr(attrs, ["display_name", :display_name])),
          session: ensure_map(fetch_attr(attrs, ["session", :session])),
          capabilities: ensure_map(fetch_attr(attrs, ["capabilities", :capabilities])),
          metadata: ensure_map(fetch_attr(attrs, ["metadata", :metadata])),
          last_synced_at: timestamp
        }

        with {:ok, account} <- upsert_account(params),
             :ok <- replace_contacts(account, attrs),
             :ok <- replace_channels(account, attrs) do
          maybe_preload(account)
        else
          {:error, reason} -> Repo.rollback(reason)
        end
      end)
    end
  end

  defp upsert_account(params) do
    %BridgeAccount{}
    |> BridgeAccount.changeset(params)
    |> Repo.insert(
      on_conflict:
        {:replace,
         [
           :external_id,
           :display_name,
           :session,
           :capabilities,
           :metadata,
           :last_synced_at,
           :updated_at
         ]},
      conflict_target: [:account_id, :service, :instance],
      returning: true
    )
  end

  defp replace_contacts(%BridgeAccount{} = account, attrs) do
    contacts =
      attrs
      |> fetch_attr(["contacts", :contacts])
      |> ensure_list()
      |> Enum.map(&normalise_contact(account.service, &1))
      |> Enum.reject(&is_nil/1)

    Repo.delete_all(from c in Contact, where: c.bridge_account_id == ^account.id)

    Enum.reduce_while(contacts, :ok, fn contact_attrs, :ok ->
      {profile, cleaned_attrs} = ensure_contact_profile(account, contact_attrs)

      attrs_with_fk =
        cleaned_attrs
        |> Map.put(:bridge_account_id, account.id)
        |> Map.put(:profile_id, profile.id)

      case %Contact{} |> Contact.changeset(attrs_with_fk) |> Repo.insert() do
        {:ok, _record} -> {:cont, :ok}
        {:error, %Changeset{} = changeset} -> {:halt, {:error, changeset}}
      end
    end)
    |> case do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp replace_channels(%BridgeAccount{} = account, attrs) do
    channels =
      attrs
      |> fetch_channels_snapshot()
      |> Enum.map(&normalise_channel(account.service, &1))
      |> Enum.reject(&is_nil/1)

    Repo.delete_all(from c in Channel, where: c.bridge_account_id == ^account.id)

    Enum.reduce_while(channels, :ok, fn channel_attrs, :ok ->
      attrs_with_fk = Map.put(channel_attrs, :bridge_account_id, account.id)

      case %Channel{} |> Channel.changeset(attrs_with_fk) |> Repo.insert() do
        {:ok, _record} -> {:cont, :ok}
        {:error, %Changeset{} = changeset} -> {:halt, {:error, changeset}}
      end
    end)
    |> case do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp fetch_channels_snapshot(attrs) do
    attrs
    |> fetch_attr(["channels", :channels])
    |> case do
      [] ->
        attrs
        |> fetch_attr(["chats", :chats])
        |> case do
          [] -> fetch_attr(attrs, ["conversations", :conversations])
          chats -> chats
        end
      channels -> channels
    end
    |> ensure_list()
  end

  defp ensure_map(value) when is_map(value), do: value
  defp ensure_map(_), do: %{}

  defp ensure_list(value) when is_list(value), do: value
  defp ensure_list(value) when is_nil(value), do: []
  defp ensure_list(_), do: []

  defp resolve_instance(attrs, opts) do
    candidate =
      case Keyword.fetch(opts, :instance) do
        {:ok, value} -> value
        :error -> fetch_attr(attrs, ["instance", :instance])
      end

    candidate
    |> maybe_extract_instance()
    |> normalise_instance_default()
  end

  defp maybe_extract_instance(%{id: value}) when not is_nil(value), do: value
  defp maybe_extract_instance(%{"id" => value}) when not is_nil(value), do: value
  defp maybe_extract_instance(%{external_id: value}) when not is_nil(value), do: value
  defp maybe_extract_instance(%{"external_id" => value}) when not is_nil(value), do: value
  defp maybe_extract_instance(%{tenant: tenant}) when not is_nil(tenant), do: maybe_extract_instance(tenant)
  defp maybe_extract_instance(%{"tenant" => tenant}) when not is_nil(tenant), do: maybe_extract_instance(tenant)
  defp maybe_extract_instance(%{workspace: workspace}) when not is_nil(workspace),
    do: maybe_extract_instance(workspace)

  defp maybe_extract_instance(%{"workspace" => workspace}) when not is_nil(workspace),
    do: maybe_extract_instance(workspace)

  defp maybe_extract_instance(value), do: value

  defp normalise_instance_default(nil), do: {:ok, @default_instance}
  defp normalise_instance_default(value), do: normalise_instance(value)

  defp normalise_instance(value) when is_atom(value), do: normalise_instance(Atom.to_string(value))
  defp normalise_instance(value) when is_integer(value), do: normalise_instance(Integer.to_string(value))

  defp normalise_instance(value) when is_binary(value) do
    trimmed = String.trim(value)

    cond do
      trimmed == "" -> {:error, {:invalid_instance, value}}
      String.contains?(trimmed, "/") -> {:error, {:invalid_instance, value}}
      true -> {:ok, trimmed}
    end
  end

  defp normalise_instance(%{} = value) do
    value
    |> maybe_extract_instance()
    |> normalise_instance_default()
  end

  defp normalise_instance(value), do: {:error, {:invalid_instance, value}}

  defp normalise_contact(service, value) when is_map(value) do
    value = stringify_keys(value)

    external_id =
      value["external_id"] || value["id"] || value["uuid"] || value["jid"] || value["phone_number"]

    cond do
      not is_binary(external_id) or external_id == "" -> nil
      true ->
        display_name =
          value["display_name"] ||
            value["name"] ||
            build_name(value["first_name"], value["last_name"]) ||
            value["username"] ||
            value["phone_number"] ||
            external_id

        handle = value["username"] || value["handle"]

        metadata =
          value
          |> Map.take([
            "phone_number",
            "phone",
            "msisdn",
            "email",
            "emails",
            "first_name",
            "last_name",
            "username",
            "type",
            "jid"
          ])
          |> Map.merge(extract_metadata(value))
          |> compact_map()

        match_keys =
          build_match_keys(service, value)
          |> Enum.reject(&is_nil/1)

        %{
          external_id: to_string(external_id),
          display_name: safe_string(display_name),
          handle: safe_string(handle),
          metadata: metadata,
          match_keys: match_keys
        }
    end
  end

  defp normalise_contact(_service, _value), do: nil

  defp normalise_channel(service, value) when is_map(value) do
    value = stringify_keys(value)

    external_id =
      value["external_id"] || value["id"] || value["chat_id"] || value["peer_id"] || value["jid"]

    cond do
      not is_binary(external_id) and not is_integer(external_id) -> nil
      true ->
        name =
          value["name"] ||
            value["title"] ||
            value["display_name"] ||
            value["username"] ||
            to_string(external_id)

        kind =
          value["kind"] ||
            value["type"] ||
            default_channel_kind(service, value)

        metadata =
          value
          |> Map.take(["type", "kind", "topic", "role", "muted", "participant_count", "invite_link"])
          |> Map.merge(extract_metadata(value))
          |> compact_map()

        %{
          external_id: to_string(external_id),
          name: safe_string(name),
          kind: safe_string(kind) || "chat",
          topic: safe_string(value["topic"]),
          role: safe_string(value["role"]),
          muted: !!value["muted"],
          metadata: metadata
        }
    end
  end

  defp normalise_channel(_service, _value), do: nil

  defp extract_metadata(value) do
    case value["metadata"] do
      metadata when is_map(metadata) -> stringify_keys(metadata)
      _ -> %{}
    end
  end

  defp compact_map(map) do
    map
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp build_name(first, last) do
    [first, last]
    |> Enum.filter(&(is_binary(&1) and &1 != ""))
    |> case do
      [] -> nil
      parts -> Enum.join(parts, " ")
    end
  end

  defp stringify_keys(map) do
    map
    |> Enum.map(fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      {key, value} when is_binary(key) -> {key, value}
      {key, value} -> {to_string(key), value}
    end)
    |> Map.new()
  end

  defp safe_string(value) when is_binary(value), do: String.trim(value)
  defp safe_string(value) when is_integer(value), do: Integer.to_string(value)
  defp safe_string(_), do: nil

  defp fetch_attr(attrs, keys) when is_list(keys) do
    Enum.reduce_while(keys, nil, fn key, acc ->
      case acc do
        nil -> {:cont, do_fetch_attr(attrs, key)}
        value -> {:halt, value}
      end
    end)
  end

  defp do_fetch_attr(attrs, key) when is_atom(key) do
    case attrs do
      %{^key => value} -> value
      _ ->
        string_key = Atom.to_string(key)
        case attrs do
          %{^string_key => value} -> value
          _ -> nil
        end
    end
  end

  defp do_fetch_attr(attrs, key) when is_binary(key) do
    case attrs do
      %{^key => value} -> value
      _ ->
        atom_key = String.to_existing_atom(key)
        attrs[atom_key]
    rescue
      ArgumentError -> nil
    end
  end

  defp maybe_preload(nil), do: nil

  defp maybe_preload(account) do
    Repo.preload(account, contacts: [:profile], channels: [])
  end

  @doc """
  Lists the aggregated contact profiles for a given Msgr account.
  """
  @spec list_profiles(account_id()) :: [ContactProfile.t()]
  def list_profiles(account_id) do
    profile_ids =
      fetch_profile_ids_for_account(account_id)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    case profile_ids do
      [] -> []
      ids ->
        Repo.all(
          from p in ContactProfile,
            where: p.id in ^ids,
            preload: [contacts: [:bridge_account], keys: [], links: []],
            order_by: [asc: p.canonical_name, asc: p.inserted_at]
        )
    end
  end

  @doc """
  Links a native Msgr contact into the bridge profile graph, returning the
  associated profile after keys have been recorded.
  """
  @spec link_msgr_contact(MsgrContact.t()) :: {:ok, ContactProfile.t()} | {:error, term()}
  def link_msgr_contact(%MsgrContact{} = contact) do
    keys =
      []
      |> maybe_add_key("email", contact.email, 80)
      |> maybe_add_key("phone", contact.phone_number, 90)
      |> maybe_add_key("msgr-contact", contact.id, 100)

    with_keys =
      keys
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq_by(&{&1.kind, &1.value})

    case with_keys do
      [] -> {:error, :no_match_keys}
      match_keys ->
        Repo.transaction(fn ->
          {:ok, profile} = ensure_profile_from_keys(match_keys, contact.name, contact.metadata || %{})

          link_metadata = %{
            "account_id" => to_string(contact.account_id),
            "contact_id" => to_string(contact.id)
          }

          ensure_profile_link(profile, :msgr_contact, contact.id, link_metadata)
          maybe_update_profile_name(profile, contact.name)

          Repo.preload(profile, [:keys, :links])
        end)
    end
  end

  defp fetch_profile_ids_for_account(account_id) do
    account_id_str = to_string(account_id)

    bridge_profile_ids =
      Repo.all(
        from c in Contact,
          join: ba in assoc(c, :bridge_account),
          where: ba.account_id == ^account_id,
          select: c.profile_id
      )

    msgr_profile_ids =
      Repo.all(
        from l in ProfileLink,
          where: l.source == "msgr_contact" and fragment("?->>'account_id' = ?", l.metadata, ^account_id_str),
          select: l.profile_id
      )

    bridge_profile_ids ++ msgr_profile_ids
  end

  defp ensure_contact_profile(%BridgeAccount{} = account, %{match_keys: keys} = contact_attrs) do
    metadata = ensure_map(Map.get(contact_attrs, :metadata, %{}))

    base_keys =
      keys
      |> normalise_keys()
      |> maybe_add_key("bridge-contact", "#{account.id}:#{contact_attrs.external_id}", 100)
      |> maybe_add_key("service-contact:#{account.service}", contact_attrs.external_id, 60)
      |> maybe_add_key("email", metadata["email"], 80)
      |> maybe_add_key("phone", metadata["phone_number"], 90)
      |> maybe_add_key("handle", metadata["username"], 50)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq_by(&{&1.kind, &1.value})

    {:ok, profile} = ensure_profile_from_keys(base_keys, contact_attrs.display_name, metadata)

    {profile, Map.delete(contact_attrs, :match_keys)}
  end

  defp ensure_profile_from_keys(keys, fallback_name, metadata) do
    with {:ok, profile} <- resolve_profile_from_keys(keys, fallback_name, metadata) do
      attach_keys(profile, keys)
      updated = maybe_update_profile_name(profile, fallback_name)
      {:ok, updated}
    end
  end

  defp resolve_profile_from_keys([], fallback_name, metadata) do
    create_profile(fallback_name, metadata)
  end

  defp resolve_profile_from_keys(keys, fallback_name, metadata) do
    profile_ids =
      keys
      |> find_profile_keys()
      |> Enum.map(& &1.profile_id)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    profile =
      case profile_ids do
        [] ->
          case create_profile(fallback_name, metadata) do
            {:ok, created} -> created
            {:error, reason} -> Repo.rollback(reason)
          end

        [id] -> Repo.get!(ContactProfile, id)
        [primary_id | rest] -> merge_profiles(primary_id, rest)
      end

    {:ok, profile}
  end

  defp create_profile(name, metadata) do
    params = %{canonical_name: safe_string(name), metadata: ensure_map(metadata)}

    %ContactProfile{}
    |> ContactProfile.changeset(params)
    |> Repo.insert()
  end

  defp attach_keys(profile, keys) do
    Enum.each(keys, fn %{kind: kind, value: value, confidence: confidence} ->
      attrs = %{profile_id: profile.id, kind: kind, value: value, confidence: confidence}

      %ContactProfileKey{}
      |> ContactProfileKey.changeset(attrs)
      |> Repo.insert(on_conflict: :nothing)
    end)
  end

  defp maybe_update_profile_name(%ContactProfile{} = profile, nil), do: profile
  defp maybe_update_profile_name(%ContactProfile{} = profile, ""), do: profile

  defp maybe_update_profile_name(%ContactProfile{} = profile, name) do
    cond do
      is_nil(profile.canonical_name) and is_binary(name) ->
        {:ok, updated} =
          profile
          |> ContactProfile.changeset(%{canonical_name: safe_string(name)})
          |> Repo.update()

        updated

      true -> profile
    end
  end

  defp find_profile_keys(keys) do
    Enum.reduce(keys, dynamic(false), fn %{kind: kind, value: value}, dynamic ->
      dynamic([k], ^dynamic or (k.kind == ^kind and k.value == ^value))
    end)
    |> case do
      dynamic when dynamic != false -> Repo.all(from k in ContactProfileKey, where: ^dynamic)
      _ -> []
    end
  end

  defp merge_profiles(primary_id, []), do: Repo.get!(ContactProfile, primary_id)

  defp merge_profiles(primary_id, other_ids) do
    primary = Repo.get!(ContactProfile, primary_id)

    Enum.each(other_ids, fn id ->
      other = Repo.get(ContactProfile, id)

      if other do
        transfer_keys(other, primary)

        Repo.update_all(from(c in Contact, where: c.profile_id == ^other.id), set: [profile_id: primary.id])

        Repo.update_all(from(l in ProfileLink, where: l.profile_id == ^other.id), set: [profile_id: primary.id])

        Repo.delete(other)
      end
    end)

    primary
  end

  defp transfer_keys(nil, _primary), do: :ok

  defp transfer_keys(other, primary) do
    keys = Repo.all(from k in ContactProfileKey, where: k.profile_id == ^other.id)

    Enum.each(keys, fn key ->
      attrs = %{profile_id: primary.id, kind: key.kind, value: key.value, confidence: key.confidence}

      %ContactProfileKey{}
      |> ContactProfileKey.changeset(attrs)
      |> Repo.insert(on_conflict: :nothing)
    end)

    Repo.delete_all(from k in ContactProfileKey, where: k.profile_id == ^other.id)
  end

  defp ensure_profile_link(%ContactProfile{} = profile, source, source_id, metadata) do
    attrs = %{
      profile_id: profile.id,
      source: source,
      source_id: to_string(source_id),
      metadata: ensure_map(metadata)
    }

    %ProfileLink{}
    |> ProfileLink.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:metadata, :updated_at]},
      conflict_target: [:source, :source_id]
    )

    profile
  end

  defp normalise_keys(nil), do: []
  defp normalise_keys(keys) when is_list(keys), do: Enum.map(keys, &normalise_key/1)
  defp normalise_keys(_), do: []

  defp normalise_key(nil), do: nil
  defp normalise_key({kind, value}), do: normalise_key(%{kind: kind, value: value})

  defp normalise_key(%{kind: kind, value: value} = key) do
    kind =
      kind
      |> to_string()
      |> String.trim()
      |> String.downcase()

    value = normalise_key_value(kind, value)

    confidence = Map.get(key, :confidence) || Map.get(key, "confidence") || 1

    if is_nil(value) or value == "" do
      nil
    else
      %{kind: kind, value: value, confidence: confidence}
    end
  end

  defp normalise_key(_), do: nil

  defp normalise_key_value(_kind, nil), do: nil
  defp normalise_key_value(_kind, ""), do: nil

  defp normalise_key_value(kind, value) do
    cond do
      kind == "email" -> value |> to_string() |> String.trim() |> String.downcase()
      kind == "phone" -> value |> to_string() |> String.replace(~r/\D+/, "")
      String.starts_with?(kind, "handle") -> value |> to_string() |> String.trim() |> String.downcase()
      true -> value |> to_string() |> String.trim()
    end
  end

  defp maybe_add_key(keys, _kind, value, _confidence) when value in [nil, ""], do: keys
  defp maybe_add_key(keys, kind, values, confidence) when is_list(values) do
    Enum.reduce(values, keys, fn value, acc -> maybe_add_key(acc, kind, value, confidence) end)
  end

  defp maybe_add_key(keys, kind, value, confidence) do
    [%{kind: kind, value: value, confidence: confidence} | keys]
  end

  defp ensure_map(value) when is_map(value), do: value
  defp ensure_map(_), do: %{}

  defp build_match_keys(service, value) do
    []
    |> maybe_add_key("email", value["email"], 80)
    |> maybe_add_key("email", value["emails"], 80)
    |> maybe_add_key("phone", value["phone_number"], 90)
    |> maybe_add_key("phone", value["phone"], 90)
    |> maybe_add_key("phone", value["msisdn"], 90)
    |> maybe_add_key("jid", value["jid"], 70)
    |> maybe_add_key("handle", value["username"], 50)
    |> maybe_add_key("handle", value["handle"], 50)
    |> maybe_add_key("handle:#{service}", value["username"], 60)
    |> maybe_add_key("handle:#{service}", value["handle"], 60)
  end

  defp default_channel_kind(service, value) do
    type = stringify_keys(value)["type"]

    cond do
      type in ["supergroup", "megagroup"] -> "supergroup"
      type == "channel" -> "channel"
      type == "group" -> "group"
      String.contains?(service, "signal") -> "conversation"
      true -> "chat"
    end
  end

  defp normalise_service(service) when is_atom(service), do: Atom.to_string(service)
  defp normalise_service(service) when is_binary(service), do: String.downcase(String.trim(service))
end
