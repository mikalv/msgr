defmodule MessngrWeb.NoiseHandshakeJSON do
  alias Messngr.Transport.Noise.Session

  def create(%{payload: payload}) do
    session = payload.session

    %{
      data: %{
        session_id: Session.id(session),
        signature: payload.signature,
        device_key: payload.device_key,
        device_private_key: payload.device_private_key,
        expires_at: DateTime.to_iso8601(payload.expires_at),
        server: normalize_server(payload.server)
      }
    }
  end

  defp normalize_server(server) when is_map(server) do
    server
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Enum.into(%{})
  end
end
