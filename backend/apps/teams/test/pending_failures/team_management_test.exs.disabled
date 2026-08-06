defmodule Teams.TeamManagementTest do
  use Teams.DataCase

  alias Teams.TeamManagement
  alias Teams.Tenancy
  alias Teams.Schemas.{Team, TeamMembership}

  setup do
    # Create a global account for the owner
    {:ok, account} =
      Messngr.Accounts.create_account(%{
        "display_name" => "Test Owner",
        "email" => "owner-#{Ecto.UUID.generate()}@example.com"
      })

    on_exit(fn ->
      # Clean up any tenant schemas created during the test
      for schema <- Tenancy.list_tenants(),
          String.starts_with?(schema, "tenant_") do
        try do
          Ecto.Adapters.SQL.query!(Teams.Repo, "DROP SCHEMA IF EXISTS \"#{schema}\" CASCADE")
        rescue
          _ -> :ok
        end
      end
    end)

    {:ok, account: account}
  end

  describe "create_team/1" do
    test "creates team with tenant schema, owner membership, and #general channel", %{
      account: account
    } do
      {:ok, team} =
        TeamManagement.create_team(%{
          name: "Acme Corp",
          slug: "acme-corp",
          owner_account_id: account.id
        })

      assert team.name == "Acme Corp"
      assert team.slug == "acme-corp"
      assert team.owner_account_id == account.id
      assert team.schema_name =~ "tenant_"

      # Owner should be a member
      assert TeamManagement.member?(team.id, account.id)

      # Owner profile should exist in tenant
      profile = TeamManagement.get_profile_for_account(team.schema_name, account.id)
      assert profile != nil
      assert profile.role == "owner"

      # #general channel should exist
      channels = Teams.Channels.list_channels(team.schema_name)
      slugs = Enum.map(channels, & &1.slug)
      assert "general" in slugs
    end

    test "returns error for missing required fields" do
      assert_raise Ecto.InvalidChangesetError, fn ->
        TeamManagement.create_team(%{name: "No Slug"})
      end
    end
  end

  describe "join_team/3" do
    setup %{account: owner} do
      {:ok, team} =
        TeamManagement.create_team(%{
          name: "Join Test",
          slug: "join-test-#{Ecto.UUID.generate() |> binary_part(0, 8)}",
          owner_account_id: owner.id
        })

      {:ok, new_account} =
        Messngr.Accounts.create_account(%{
          "display_name" => "New Member",
          "email" => "member-#{Ecto.UUID.generate()}@example.com"
        })

      {:ok, team: team, new_account: new_account}
    end

    test "creates membership, tenant profile, and joins #general", %{
      team: team,
      new_account: new_account
    } do
      {:ok, result} = TeamManagement.join_team(team, new_account.id)

      assert result.membership.account_id == new_account.id
      assert result.membership.team_id == team.id
      assert result.membership.role == "member"

      assert result.profile.account_id == new_account.id
      assert result.profile.display_name == "New Member"
    end

    test "uses custom display_name when provided", %{team: team, new_account: new_account} do
      {:ok, result} =
        TeamManagement.join_team(team, new_account.id, %{display_name: "Custom Name"})

      assert result.profile.display_name == "Custom Name"
    end

    test "uses custom role when provided", %{team: team, new_account: new_account} do
      {:ok, result} = TeamManagement.join_team(team, new_account.id, %{role: "admin"})
      assert result.membership.role == "admin"
    end
  end

  describe "list_teams_for_account/1" do
    test "returns teams the account belongs to", %{account: account} do
      {:ok, team1} =
        TeamManagement.create_team(%{
          name: "Team One",
          slug: "team-one-#{Ecto.UUID.generate() |> binary_part(0, 8)}",
          owner_account_id: account.id
        })

      {:ok, team2} =
        TeamManagement.create_team(%{
          name: "Team Two",
          slug: "team-two-#{Ecto.UUID.generate() |> binary_part(0, 8)}",
          owner_account_id: account.id
        })

      teams = TeamManagement.list_teams_for_account(account.id)
      team_ids = Enum.map(teams, & &1.id)

      assert team1.id in team_ids
      assert team2.id in team_ids
    end

    test "returns empty list for account with no teams" do
      {:ok, lonely} =
        Messngr.Accounts.create_account(%{
          "display_name" => "Lonely",
          "email" => "lonely-#{Ecto.UUID.generate()}@example.com"
        })

      assert TeamManagement.list_teams_for_account(lonely.id) == []
    end
  end

  describe "member?/2" do
    test "returns true for team member", %{account: account} do
      {:ok, team} =
        TeamManagement.create_team(%{
          name: "Member Check",
          slug: "member-check-#{Ecto.UUID.generate() |> binary_part(0, 8)}",
          owner_account_id: account.id
        })

      assert TeamManagement.member?(team.id, account.id) == true
    end

    test "returns false for non-member", %{account: _account} do
      random_id = Ecto.UUID.generate()
      assert TeamManagement.member?(Ecto.UUID.generate(), random_id) == false
    end
  end

  describe "get_profile_for_account/2" do
    test "returns tenant profile for account", %{account: account} do
      {:ok, team} =
        TeamManagement.create_team(%{
          name: "Profile Test",
          slug: "profile-test-#{Ecto.UUID.generate() |> binary_part(0, 8)}",
          owner_account_id: account.id
        })

      profile = TeamManagement.get_profile_for_account(team.schema_name, account.id)
      assert profile.account_id == account.id
      assert profile.display_name == "Test Owner"
    end

    test "returns nil for non-existent account in tenant", %{account: account} do
      {:ok, team} =
        TeamManagement.create_team(%{
          name: "No Profile",
          slug: "no-profile-#{Ecto.UUID.generate() |> binary_part(0, 8)}",
          owner_account_id: account.id
        })

      assert TeamManagement.get_profile_for_account(team.schema_name, Ecto.UUID.generate()) ==
               nil
    end
  end
end
