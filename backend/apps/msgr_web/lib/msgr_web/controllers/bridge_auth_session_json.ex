defmodule MessngrWeb.BridgeAuthSessionJSON do
  alias Messngr.Bridges.Auth
  alias Messngr.Bridges.AuthSession

  @doc """
  Renders a bridge authentication session payload consumed by the Msgr client.
  """
  def show(%{session: %AuthSession{} = session}) do
    %{data: session(session)}
  end

  defp session(%AuthSession{} = session) do
    %{
      "id" => session.id,
      "account_id" => session.account_id,
      "service" => session.service,
      "state" => session.state,
      "login_method" => session.login_method,
      "auth_surface" => session.auth_surface,
      "client_context" => session.client_context,
      "metadata" => session.metadata,
      "catalog_snapshot" => session.catalog_snapshot,
      "expires_at" => encode_datetime(session.expires_at),
      "last_transition_at" => encode_datetime(session.last_transition_at),
      "authorization_path" => Auth.session_authorization_path(session),
      "callback_path" => Auth.session_callback_path(session),
      "inserted_at" => encode_datetime(session.inserted_at),
      "updated_at" => encode_datetime(session.updated_at)
    }
  end

  defp encode_datetime(nil), do: nil

  defp encode_datetime(%DateTime{} = dt) do
    dt
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601()
  end
end
