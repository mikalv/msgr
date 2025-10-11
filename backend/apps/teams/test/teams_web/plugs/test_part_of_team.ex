defmodule TeamsWeb.Plugs.PartOfTeamTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias TeamsWeb.Plugs.PartOfTeam

  @opts PartOfTeam.init([])

  setup do
    # Mock the Guardian.Plug.current_claims/1 function
    Guardian.Plug
    |> expect(:current_claims, fn _conn -> %{"sub" => "user_id"} end)

    # Mock the Teams.TenantModels.Profile.get_by_uid/2 function
    Teams.TenantModels.Profile
    |> expect(:get_by_uid, fn _subdomain, _uid -> nil end)

    :ok
  end

  test "halts the connection if the user is not part of the team" do
    conn = conn(:get, "/")
    |> put_private(:subdomain, "example")

    conn = PartOfTeam.call(conn, @opts)

    assert conn.status == 401
    assert conn.resp_body == ~s({"error":"you're not part of this team!"})
    assert conn.halted
  end

  test "allows the connection if the user is part of the team" do
    Teams.TenantModels.Profile
    |> expect(:get_by_uid, fn _subdomain, _uid -> %{} end)

    conn = conn(:get, "/")
    |> put_private(:subdomain, "example")

    conn = PartOfTeam.call(conn, @opts)

    refute conn.halted
  end
end
