defmodule MessngrWeb.BridgeCatalogJSON do
  alias Messngr.Bridges.Auth
  alias Messngr.Bridges.Auth.CatalogEntry
  alias Messngr.Bridges.AuthSession
  alias Messngr.Bridges.BridgeAccount

  @doc """
  Renders the list of bridge connectors for the catalog endpoint.
  """
  def index(%{connectors: connectors} = assigns) do
    linked_accounts = Map.get(assigns, :linked_accounts, %{})

    %{data: Enum.map(connectors, &connector(&1, linked_accounts))}
  end

  defp connector(%CatalogEntry{} = entry, linked_accounts) do
    map = CatalogEntry.to_map(entry)
    accounts = Map.get(linked_accounts, map.service, [])
    {link_status, link_payload} = link_payload(accounts)

    auth_details =
      map.auth
      |> Map.new()
      |> Map.put(:status, link_status)
      |> maybe_put_linked_at(link_payload)

    %{
      "id" => map.id,
      "service" => map.service,
      "display_name" => map.display_name,
      "description" => map.description,
      "status" => to_string(map.status),
      "auth" => stringify_keys(auth_details),
      "capabilities" => stringify_keys(map.capabilities),
      "categories" => map.categories,
      "prerequisites" => map.prerequisites,
      "tags" => map.tags,
      "auth_paths" => %{
        "start" => Auth.session_authorization_path(%AuthSession{id: ":session_id"}),
        "callback" => Auth.session_callback_path(%AuthSession{id: ":session_id"})
      },
      "link" => link_payload
    }
  end

  defp link_payload([]), do: {"not_linked", nil}

  defp link_payload(accounts) when is_list(accounts) do
    accounts_sorted = Enum.sort_by(accounts, & &1.inserted_at, &>=/2)

    connections = Enum.map(accounts_sorted, &account_payload/1)

    [primary | _] = connections

    payload =
      primary
      |> Map.put("status", "linked")
      |> Map.put("connections", connections)

    {"linked", payload}
  end

  defp account_payload(%BridgeAccount{} = account) do
    %{
      "service" => account.service,
      "instance" => account.instance,
      "display_name" => account.display_name,
      "external_id" => account.external_id,
      "linked_at" => format_datetime(account.inserted_at),
      "last_synced_at" => format_datetime(account.last_synced_at)
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp maybe_put_linked_at(auth_details, %{"linked_at" => linked_at}) when not is_nil(linked_at) do
    Map.put(auth_details, :linked_at, linked_at)
  end

  defp maybe_put_linked_at(auth_details, %{"connections" => [first | _]}) do
    maybe_put_linked_at(auth_details, first)
  end

  defp maybe_put_linked_at(auth_details, _link_payload), do: auth_details

  defp format_datetime(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp format_datetime(%NaiveDateTime{} = value), do: DateTime.from_naive!(value, "Etc/UTC") |> DateTime.to_iso8601()
  defp format_datetime(_), do: nil

  defp stringify_keys(value) when is_map(value) do
    value
    |> Enum.map(fn {key, val} -> {to_string(key), stringify_keys(val)} end)
    |> Map.new()
  end

  defp stringify_keys(value) when is_list(value), do: Enum.map(value, &stringify_keys/1)
  defp stringify_keys(value), do: value
end
