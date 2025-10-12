defmodule MessngrWeb.BridgeAuthBrowserController do
  use MessngrWeb, :controller

  alias Messngr.Bridges.Auth

  def start(conn, %{"session_id" => session_id}) do
    with {:ok, session} <- Auth.get_session(session_id),
         {:ok, _session, redirect_url} <- Auth.initiate_oauth_redirect(session) do
      redirect_to(conn, redirect_url)
    else
      {:error, :session_expired} -> expired(conn)
      {:error, :unsupported_login_method} -> bad_request(conn)
      {:error, :not_found} -> not_found(conn)
      {:error, _reason} -> bad_request(conn)
    end
  end

  def callback(conn, %{"session_id" => session_id} = params) do
    with {:ok, session} <- Auth.get_session(session_id),
         {:ok, _session, _info} <- Auth.complete_oauth_callback(session, params) do
      success_page(conn)
    else
      {:error, :session_expired} -> expired(conn)
      {:error, :state_mismatch} -> bad_request(conn)
      {:error, {:missing_param, _}} -> bad_request(conn)
      {:error, {:missing_value, _}} -> bad_request(conn)
      {:error, :unsupported_login_method} -> bad_request(conn)
      {:error, :not_found} -> not_found(conn)
      {:error, _reason} -> bad_request(conn)
    end
  end

  defp redirect_to(conn, url) when is_binary(url) do
    if String.starts_with?(url, ["http://", "https://"]) do
      redirect(conn, external: url)
    else
      redirect(conn, to: url)
    end
  end

  defp success_page(conn) do
    conn
    |> put_resp_content_type("text/html")
    |> send_resp(:ok, success_html())
  end

  defp success_html do
    """
    <!DOCTYPE html>
    <html lang=\"en\">
      <head>
        <meta charset=\"utf-8\" />
        <title>Bridge authentication complete</title>
        <style>
          body { font-family: system-ui, sans-serif; padding: 2rem; text-align: center; }
          h1 { margin-bottom: 0.5rem; }
          p { color: #3f3f46; }
        </style>
        <script>
          window.addEventListener('load', function () {
            setTimeout(function () {
              if (window.opener) { window.opener.postMessage({ event: 'msgr:bridge-auth-complete' }, '*'); }
              window.close();
            }, 500);
          });
        </script>
      </head>
      <body>
        <h1>Authentication complete</h1>
        <p>You can close this window and return to Msgr.</p>
      </body>
    </html>
    """
  end

  defp expired(conn) do
    conn
    |> put_status(:gone)
    |> text("This bridge authentication session has expired.")
  end

  defp bad_request(conn) do
    conn
    |> put_status(:bad_request)
    |> text("Unable to process bridge authentication request.")
  end

  defp not_found(conn) do
    conn
    |> put_status(:not_found)
    |> text("Bridge authentication session not found.")
  end
end
