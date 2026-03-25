defmodule MessngrWeb.Plugs.RequestLogger do
  @moduledoc """
  Custom request logger that includes remote IP and authenticated user.

  Logs: `method path → status in Xms | ip=1.2.3.4 user=account_id`

  Remote IP is extracted from X-Forwarded-For (set by proxyengine)
  or falls back to conn.remote_ip.
  """

  require Logger
  @behaviour Plug

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    start = System.monotonic_time()

    Plug.Conn.register_before_send(conn, fn conn ->
      stop = System.monotonic_time()
      duration_us = System.convert_time_unit(stop - start, :native, :microsecond)
      duration = format_duration(duration_us)

      ip = client_ip(conn)
      account = account_id(conn)
      method = conn.method
      path = conn.request_path
      status = conn.status

      Logger.info("#{method} #{path} → #{status} in #{duration} | ip=#{ip} user=#{account}")

      conn
    end)
  end

  defp client_ip(conn) do
    case Plug.Conn.get_req_header(conn, "x-forwarded-for") do
      [forwarded | _] ->
        forwarded
        |> String.split(",")
        |> List.first()
        |> String.trim()

      [] ->
        conn.remote_ip
        |> :inet.ntoa()
        |> to_string()
    end
  end

  defp account_id(conn) do
    case conn.assigns do
      %{current_account: %{id: id}} when is_binary(id) ->
        String.slice(id, 0, 8)

      _ ->
        "-"
    end
  end

  defp format_duration(us) when us < 1000, do: "#{us}µs"
  defp format_duration(us), do: "#{div(us, 1000)}ms"
end
