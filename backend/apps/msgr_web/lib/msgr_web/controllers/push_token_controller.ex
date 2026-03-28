defmodule MessngrWeb.PushTokenController do
  use MessngrWeb, :controller

  action_fallback MessngrWeb.FallbackController

  @doc "POST /api/push/register — register a device push token"
  def register(conn, %{"token" => token, "platform" => platform} = params) do
    account = conn.assigns.current_account

    unless account do
      {:error, :forbidden}
    else
      attrs = %{
        account_id: account.id,
        token: token,
        platform: platform,
        device_name: Map.get(params, "device_name"),
        enabled: true
      }

      case Messngr.Repo.insert(
             %Messngr.Push.DeviceToken{}
             |> Ecto.Changeset.change(attrs),
             on_conflict: {:replace, [:enabled, :device_name, :updated_at]},
             conflict_target: [:account_id, :token]
           ) do
        {:ok, _} ->
          json(conn, %{ok: true})

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  def register(conn, _params) do
    conn |> put_status(:bad_request) |> json(%{error: "token and platform required"})
  end

  @doc "GET /api/push/vapid_key — return the VAPID public key for Web Push subscription"
  def vapid_key(conn, _params) do
    vapid_config = Application.get_env(:msgr, Messngr.Push.WebPush, [])
    public_key = vapid_config[:public_key]

    if public_key do
      json(conn, %{vapid_public_key: public_key})
    else
      conn |> put_status(:not_found) |> json(%{error: "Web push not configured"})
    end
  end
end
