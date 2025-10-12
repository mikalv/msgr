defmodule MessngrWeb.BridgeCatalogController do
  use MessngrWeb, :controller

  alias Messngr.Bridges
  alias Messngr.Bridges.Auth

  action_fallback MessngrWeb.FallbackController

  def index(conn, params) do
    status_filter = parse_status(params)

    entries =
      case status_filter do
        nil -> Auth.list_catalog()
        status -> Auth.list_catalog(status: status)
      end

    linked_accounts = current_linked_accounts(conn)

    render(conn, :index, connectors: entries, linked_accounts: linked_accounts)
  end

  defp parse_status(%{"status" => status}), do: parse_status(status)
  defp parse_status(status) when status in ["available", "coming_soon"], do: String.to_existing_atom(status)
  defp parse_status(_), do: nil

  defp current_linked_accounts(%{assigns: %{current_account: %{id: account_id}}})
       when is_binary(account_id) do
    account_id
    |> Bridges.list_accounts()
    |> Map.new(&{&1.service, &1})
  end

  defp current_linked_accounts(_conn), do: %{}
end
