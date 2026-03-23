defmodule MessngrWeb.Plugs.SpaFallback do
  @moduledoc """
  Serves the Flutter web client's index.html for any request that hasn't
  been handled by the router (SPA catch-all).

  Skips API routes, WebSocket paths, and health endpoints.
  """

  import Plug.Conn

  @index_path "/app/web_client/index.html"

  def init(opts), do: opts

  def call(%{state: :sent} = conn, _opts), do: conn

  def call(conn, _opts) do
    path = conn.request_path

    cond do
      # Skip API, socket, health, metrics paths
      String.starts_with?(path, "/api") -> conn
      String.starts_with?(path, "/socket") -> conn
      String.starts_with?(path, "/health") -> conn
      String.starts_with?(path, "/metrics") -> conn
      String.starts_with?(path, "/phoenix") -> conn

      # Serve index.html if it exists
      File.exists?(@index_path) ->
        conn
        |> put_resp_content_type("text/html")
        |> send_file(200, @index_path)
        |> halt()

      true ->
        conn
    end
  end
end
