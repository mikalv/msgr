defmodule MessngrWeb.ContactController do
  use MessngrWeb, :controller

  alias Messngr

  action_fallback MessngrWeb.FallbackController

  def import(conn, %{"contacts" => contacts}) when is_list(contacts) do
    current_account = conn.assigns.current_account
    current_profile = conn.assigns.current_profile

    with {:ok, imported} <- Messngr.import_contacts(current_account.id, contacts, profile_id: current_profile.id) do
      render(conn, :index, contacts: imported)
    end
  end

  def import(_conn, _params), do: {:error, :bad_request}

  def lookup(conn, %{"targets" => targets}) when is_list(targets) do
    with {:ok, matches} <- Messngr.lookup_known_contacts(targets) do
      render(conn, :lookup, matches: matches)
    end
  end

  def lookup(_conn, _params), do: {:error, :bad_request}
end
