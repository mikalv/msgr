defmodule MainProxy.Plug.DefaultTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias MainProxy.Plug.Default

  @opts Default.init([])

  test "calls the default endpoint when configured" do
    Application.put_env(:edge_router, :default_endpoint, MainProxy.Plug.FakeEndpoint)

    conn = conn(:get, "/")
    conn = Default.call(conn, @opts)

    assert conn.status == 200
    assert conn.resp_body == "Fake Endpoint"
  end

  test "calls the NotFound endpoint when no default is configured" do
    Application.delete_env(:edge_router, :default_endpoint)

    conn = conn(:get, "/")
    conn = Default.call(conn, @opts)

    assert conn.status == 404
    assert conn.resp_body == "Not Found"
  end
end

defmodule MainProxy.Plug.FakeEndpoint do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, "Fake Endpoint")
  end
end

defmodule MainProxy.Plug.NotFound do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(404, "Not Found")
  end
end
