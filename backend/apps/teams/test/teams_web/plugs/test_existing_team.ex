defmodule TeamsWeb.Plugs.ExistingTeamTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias TeamsWeb.Plugs.ExistingTeam

  @opts ExistingTeam.init([])

  describe "call/2" do
    test "puts tenant in private when team exists" do
      subdomain = "existing_subdomain"
      team = %Teams.TenantTeam{name: "Existing Team"}

      # Mock the get_team! function
      Teams.TenantTeam
      |> expect(:get_team!, fn ^subdomain -> team end)

      conn = conn(:get, "/")
             |> put_private(:subdomain, subdomain)
             |> ExistingTeam.call(@opts)

      assert conn.private[:tenant] == team.name
      assert conn.status == nil
    end

    test "sends 400 response when team does not exist" do
      subdomain = "non_existing_subdomain"

      # Mock the get_team! function to raise Ecto.NoResultsError
      Teams.TenantTeam
      |> expect(:get_team!, fn ^subdomain -> raise Ecto.NoResultsError end)

      conn = conn(:get, "/")
             |> put_private(:subdomain, subdomain)
             |> ExistingTeam.call(@opts)

      assert conn.status == 400
      assert conn.resp_body == "Teams don't exist!"
    end
  end
end
