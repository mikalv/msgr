defmodule AuthProvider.RemoteIpTest do
  use ExUnit.Case, async: true
  alias AuthProvider.RemoteIp
  import Plug.Conn

  test "returns the first IP from x-forwarded-for header" do
    conn = %Plug.Conn{
      req_headers: [{"x-forwarded-for", "192.168.0.1, 192.168.0.2"}]
    }

    assert RemoteIp.get(conn) == "192.168.0.1"
  end

  test "returns the remote_ip if x-forwarded-for header is not present" do
    conn = %Plug.Conn{
      remote_ip: {127, 0, 0, 1}
    }

    assert RemoteIp.get(conn) == "127.0.0.1"
  end

  test "returns the first trimmed IP from x-forwarded-for header" do
    conn = %Plug.Conn{
      req_headers: [{"x-forwarded-for", " 192.168.0.1 , 192.168.0.2 "}]
    }

    assert RemoteIp.get(conn) == "192.168.0.1"
  end

  test "returns the remote_ip if x-forwarded-for header is empty" do
    conn = %Plug.Conn{
      req_headers: [{"x-forwarded-for", ""}],
      remote_ip: {127, 0, 0, 1}
    }

    assert RemoteIp.get(conn) == "127.0.0.1"
  end
end
