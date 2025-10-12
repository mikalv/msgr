defmodule MessngrWeb.BridgeCatalogController do
  use MessngrWeb, :controller

  alias Messngr.Bridges.Auth

  action_fallback MessngrWeb.FallbackController

  def index(conn, params) do
    status_filter = parse_status(params)

    entries =
      case status_filter do
        nil -> Auth.list_catalog()
        status -> Auth.list_catalog(status: status)
      end

    render(conn, :index, connectors: entries)
  end

  defp parse_status(%{"status" => status}), do: parse_status(status)
  defp parse_status(status) when status in ["available", "coming_soon"], do: String.to_existing_atom(status)
  defp parse_status(_), do: nil
end
