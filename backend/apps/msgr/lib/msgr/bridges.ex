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
  alias Messngr.Bridges.{BridgeAccount, Channel, Contact}
  alias Messngr.Repo

  @type service :: atom() | String.t()
  @type account_id :: binary()
  @type sync_attrs :: map()

  @doc """
  Fetches a bridge account for the given service if one has been synced.
  """
  @spec get_account(account_id(), service()) :: BridgeAccount.t() | nil
  def get_account(account_id, service) do
    Repo.get_by(BridgeAccount, account_id: account_id, service: normalise_service(service))
    |> maybe_preload()
  end

  @doc """
  Synchronises a bridge identity, replacing contacts/channels with the snapshot provided.
  """
  @spec sync_linked_identity(account_id(), service(), sync_attrs()) ::
          {:ok, BridgeAccount.t()} | {:error, Changeset.t() | term()}
  def sync_linked_identity(account_id, service, attrs \\ %{}) do
    service = normalise_service(service)
    timestamp = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.transaction(fn ->
      params = %{
        account_id: account_id,
        service: service,
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

  defp upsert_account(params) do
    %BridgeAccount{}
    |> BridgeAccount.changeset(params)
    |> Repo.insert(
      on_conflict:
        {:replace, [:external_id, :display_name, :session, :capabilities, :metadata, :last_synced_at, :updated_at]},
      conflict_target: [:account_id, :service],
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
      attrs_with_fk = Map.put(contact_attrs, :bridge_account_id, account.id)

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
          |> Map.take(["phone_number", "first_name", "last_name", "username", "type", "jid"])
          |> Map.merge(extract_metadata(value))
          |> compact_map()

        %{
          external_id: to_string(external_id),
          display_name: safe_string(display_name),
          handle: safe_string(handle),
          metadata: metadata
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
    Repo.preload(account, [:contacts, :channels])
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
