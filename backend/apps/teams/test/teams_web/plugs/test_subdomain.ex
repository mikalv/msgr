defmodule TeamsWeb.Plugs.SubdomainTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias TeamsWeb.Plugs.Subdomain

  @opts Subdomain.init(%{subdomain_router: FakeRouter})

  defmodule FakeRouter do
    def init(opts), do: opts
    def call(conn, _opts), do: conn
  end

  defmodule FakeExistingTeamPlug do
    def call(conn, _opts), do: conn
  end

  setup do
    Application.put_env(:teams, TeamsWeb.Endpoint, url: [host: "example.com"])
    :ok
  end

  test "calls the subdomain router when subdomain is present" do
    conn = conn(:get, "/")
    |> put_req_header("host", "sub.example.com")

    conn = Subdomain.call(conn, @opts)

    assert conn.private[:subdomain] == "sub"
    assert conn.halted
  end

  test "does not call the subdomain router when subdomain is not present" do
    conn = conn(:get, "/")
    |> put_req_header("host", "example.com")

    conn = Subdomain.call(conn, @opts)

    refute conn.private[:subdomain]
    refute conn.halted
  end

  test "extract_subdomain/2 extracts the subdomain correctly" do
    assert Subdomain.extract_subdomain("sub.example.com", "example.com") == "sub"
    assert Subdomain.extract_subdomain("example.com", "example.com") == ""
  end
end
