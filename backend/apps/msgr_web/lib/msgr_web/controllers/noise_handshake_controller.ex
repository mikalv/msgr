defmodule MessngrWeb.NoiseHandshakeController do
  use MessngrWeb, :controller

  alias Messngr.Noise.DevHandshake
  alias Messngr.Transport.Noise.Session

  action_fallback MessngrWeb.FallbackController

  def create(conn, _params) do
    cond do
      not stub_enabled?() ->
        {:error, :not_found}

      not DevHandshake.enabled?() ->
        {:error, :not_found}

      true ->
        case DevHandshake.generate() do
          {:ok, payload} ->
            render(conn, :create, payload: payload)

          {:error, :noise_transport_disabled} ->
            {:error, :service_unavailable}

          {:error, :dev_handshake_disabled} ->
            {:error, :not_found}

          {:error, {:registry_start_failed, reason}} ->
            conn
            |> put_status(:internal_server_error)
            |> json(%{error: "noise_registry_failed", reason: inspect(reason)})

          {:error, reason} ->
            conn
            |> put_status(:internal_server_error)
            |> json(%{error: "noise_handshake_failed", reason: inspect(reason)})
        end
    end
  end

  defp stub_enabled? do
    Application.get_env(:msgr_web, :noise_handshake_stub, [])
    |> Keyword.get(:enabled, false)
  end
end
