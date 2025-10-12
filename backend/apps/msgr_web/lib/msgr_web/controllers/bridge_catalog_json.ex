defmodule MessngrWeb.BridgeCatalogJSON do
  alias Messngr.Bridges.Auth
  alias Messngr.Bridges.Auth.CatalogEntry
  alias Messngr.Bridges.AuthSession

  @doc """
  Renders the list of bridge connectors for the catalog endpoint.
  """
  def index(%{connectors: connectors}) do
    %{data: Enum.map(connectors, &connector/1)}
  end

  defp connector(%CatalogEntry{} = entry) do
    map = CatalogEntry.to_map(entry)

    %{
      "id" => map.id,
      "service" => map.service,
      "display_name" => map.display_name,
      "description" => map.description,
      "status" => to_string(map.status),
      "auth" => stringify_keys(map.auth),
      "capabilities" => stringify_keys(map.capabilities),
      "categories" => map.categories,
      "prerequisites" => map.prerequisites,
      "tags" => map.tags,
      "auth_paths" => %{
        "start" => Auth.session_authorization_path(%AuthSession{id: ":session_id"}),
        "callback" => Auth.session_callback_path(%AuthSession{id: ":session_id"})
      }
    }
  end

  defp stringify_keys(value) when is_map(value) do
    value
    |> Enum.map(fn {key, val} -> {to_string(key), stringify_keys(val)} end)
    |> Map.new()
  end

  defp stringify_keys(value) when is_list(value), do: Enum.map(value, &stringify_keys/1)
  defp stringify_keys(value), do: value
end
