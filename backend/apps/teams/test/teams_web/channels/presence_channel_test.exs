defmodule TeamsWeb.PresenceChannelTest do
  use TeamsWeb.ChannelCase, async: false

  alias Teams.TeamManagement
  alias Teams.Tenancy

  setup do
    # Sandbox Messngr.Repo too — create_account writes to it
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Messngr.Repo, shared: true)
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    # Create account + team + membership
    {:ok, account} =
      Messngr.Accounts.create_account(%{
        "display_name" => "Presence Tester",
        "email" => "presence-#{Ecto.UUID.generate()}@example.com"
      })

    slug = "presence-test-#{System.unique_integer([:positive])}"

    {:ok, team} =
      TeamManagement.create_team(%{
        name: "Presence Team",
        slug: slug,
        owner_account_id: account.id
      })

    profile = TeamManagement.get_profile_for_account(team.schema_name, account.id)

    on_exit(fn ->
      for schema <- Tenancy.list_tenants(),
          String.starts_with?(schema, "tenant_") do
        try do
          Ecto.Adapters.SQL.query!(Teams.Repo, "DROP SCHEMA IF EXISTS \"#{schema}\" CASCADE")
        rescue
          _ -> :ok
        end
      end
    end)

    {:ok,
     account: account,
     team: team,
     profile: profile,
     slug: slug}
  end

  describe "join presence:{slug}" do
    test "succeeds for team member", %{account: account, profile: profile, slug: slug, team: team} do
      {:ok, _, socket} =
        TeamsWeb.UserSocket
        |> socket("user:#{account.id}", %{
          uid: account.id,
          profile_id: profile.id,
          tenant: team.schema_name,
          team_id: team.id
        })
        |> subscribe_and_join(TeamsWeb.PresenceChannel, "presence:#{slug}")

      assert socket.assigns.team_slug == slug
      assert socket.assigns.prefix == team.schema_name
    end

    test "assigns presence tracking after join", %{account: account, profile: profile, slug: slug, team: team} do
      {:ok, _, socket} =
        TeamsWeb.UserSocket
        |> socket("user:#{account.id}", %{
          uid: account.id,
          profile_id: profile.id,
          tenant: team.schema_name,
          team_id: team.id
        })
        |> subscribe_and_join(TeamsWeb.PresenceChannel, "presence:#{slug}")

      # The :after_join message triggers presence tracking; give it time to process
      assert_push "presence_state", presence_state, 1_000
      assert is_map(presence_state)
    end

    test "returns presence state with profile info", %{account: account, profile: profile, slug: slug, team: team} do
      {:ok, _, _socket} =
        TeamsWeb.UserSocket
        |> socket("user:#{account.id}", %{
          uid: account.id,
          profile_id: profile.id,
          tenant: team.schema_name,
          team_id: team.id
        })
        |> subscribe_and_join(TeamsWeb.PresenceChannel, "presence:#{slug}")

      assert_push "presence_state", presence_state, 1_000

      # The presence state should contain an entry keyed by profile_id
      assert Map.has_key?(presence_state, profile.id)

      [meta | _] = presence_state[profile.id]["metas"]
      assert meta["profile_id"] == profile.id
      assert meta["online_at"]
    end

    test "rejects non-member", %{slug: slug, team: team} do
      # Create a different account that is NOT a member of this team
      {:ok, outsider} =
        Messngr.Accounts.create_account(%{
          "display_name" => "Outsider",
          "email" => "outsider-#{Ecto.UUID.generate()}@example.com"
        })

      outsider_profile = hd(outsider.profiles)

      assert {:error, %{reason: "not_a_member"}} =
               TeamsWeb.UserSocket
               |> socket("user:#{outsider.id}", %{
                 uid: outsider.id,
                 profile_id: outsider_profile.id,
                 tenant: nil,
                 team_id: nil
               })
               |> subscribe_and_join(TeamsWeb.PresenceChannel, "presence:#{slug}")
    end

    test "rejects join for non-existent team" do
      {:ok, account} =
        Messngr.Accounts.create_account(%{
          "display_name" => "Nobody",
          "email" => "nobody-#{Ecto.UUID.generate()}@example.com"
        })

      nobody_profile = hd(account.profiles)

      assert {:error, %{reason: "team_not_found"}} =
               TeamsWeb.UserSocket
               |> socket("user:#{account.id}", %{
                 uid: account.id,
                 profile_id: nobody_profile.id,
                 tenant: nil,
                 team_id: nil
               })
               |> subscribe_and_join(TeamsWeb.PresenceChannel, "presence:no-such-team")
    end
  end

  describe "ping" do
    test "replies with status ok", %{account: account, profile: profile, slug: slug, team: team} do
      {:ok, _, socket} =
        TeamsWeb.UserSocket
        |> socket("user:#{account.id}", %{
          uid: account.id,
          profile_id: profile.id,
          tenant: team.schema_name,
          team_id: team.id
        })
        |> subscribe_and_join(TeamsWeb.PresenceChannel, "presence:#{slug}")

      ref = push(socket, "ping", %{"hello" => "there"})
      assert_reply ref, :ok, %{"hello" => "there"}
    end
  end
end
