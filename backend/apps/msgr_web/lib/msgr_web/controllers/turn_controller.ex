defmodule MessngrWeb.TurnController do
  use MessngrWeb, :controller

  @turn_ttl 86400
  @turn_host Application.compile_env(:msgr_web, :turn_host, "dev.msgr.no")
  @turn_port Application.compile_env(:msgr_web, :turn_port, 3478)
  @turn_secret Application.compile_env(:msgr_web, :turn_secret, "relay-turn-secret")

  action_fallback MessngrWeb.FallbackController

  def credentials(conn, _params) do
    account = conn.assigns.current_account
    expiry = System.system_time(:second) + @turn_ttl
    username = "#{expiry}:#{account.id}"
    credential = :crypto.mac(:hmac, :sha, @turn_secret, username) |> Base.encode64()

    json(conn, %{
      ice_servers: [
        %{urls: "stun:#{@turn_host}:#{@turn_port}"},
        %{
          urls: [
            "turn:#{@turn_host}:#{@turn_port}",
            "turn:#{@turn_host}:#{@turn_port}?transport=tcp"
          ],
          username: username,
          credential: credential
        }
      ]
    })
  end
end
