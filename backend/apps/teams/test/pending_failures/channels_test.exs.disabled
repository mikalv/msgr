defmodule Teams.ChannelsTest do
  use Teams.DataCase

  alias Teams.Channels
  alias Teams.TeamManagement
  alias Teams.Tenancy
  alias Teams.TenantModels.Profile

  setup do
    {:ok, account} =
      Messngr.Accounts.create_account(%{
        "display_name" => "Channel Tester",
        "email" => "channels-#{Ecto.UUID.generate()}@example.com"
      })

    {:ok, team} =
      TeamManagement.create_team(%{
        name: "Channel Test Team",
        slug: "ch-test-#{Ecto.UUID.generate() |> binary_part(0, 8)}",
        owner_account_id: account.id
      })

    prefix = team.schema_name
    profile = TeamManagement.get_profile_for_account(prefix, account.id)

    on_exit(fn ->
      try do
        Tenancy.drop_tenant(team.id)
      rescue
        _ -> :ok
      end
    end)

    {:ok, prefix: prefix, profile: profile, team: team, account: account}
  end

  describe "list_channels/1" do
    test "lists all channels in tenant", %{prefix: prefix} do
      channels = Channels.list_channels(prefix)
      # #general is seeded by create_team
      assert length(channels) >= 1
      assert Enum.any?(channels, &(&1.slug == "general"))
    end
  end

  describe "create_channel/2" do
    test "creates a channel with auto-generated slug", %{prefix: prefix, profile: profile} do
      {:ok, channel} =
        Channels.create_channel(prefix, %{
          name: "Engineering",
          visibility: "public",
          created_by: profile.id
        })

      assert channel.name == "Engineering"
      assert channel.slug == "engineering"
      assert channel.visibility == "public"
    end

    test "creates a private channel", %{prefix: prefix, profile: profile} do
      {:ok, channel} =
        Channels.create_channel(prefix, %{
          name: "Secret Ops",
          visibility: "private",
          created_by: profile.id
        })

      assert channel.visibility == "private"
    end

    test "auto-joins creator as admin", %{prefix: prefix, profile: profile} do
      {:ok, channel} =
        Channels.create_channel(prefix, %{
          name: "Auto Join",
          created_by: profile.id
        })

      members = Channels.list_members(prefix, channel.id)
      creator_member = Enum.find(members, &(&1.profile_id == profile.id))
      assert creator_member != nil
      assert creator_member.role == "admin"
    end
  end

  describe "create_dm/2" do
    test "creates a DM channel between two profiles", %{
      prefix: prefix,
      profile: profile,
      account: _account
    } do
      # Create a second profile in the tenant
      {:ok, profile2} =
        Profile.create(prefix, %{
          account_id: Ecto.UUID.generate(),
          display_name: "DM Partner",
          role: "member"
        })

      {:ok, dm} = Channels.create_dm(prefix, [profile.id, profile2.id])
      assert dm.kind == "dm"
      assert dm.visibility == "private"
    end

    test "deduplicates DM channels", %{prefix: prefix, profile: profile} do
      {:ok, profile2} =
        Profile.create(prefix, %{
          account_id: Ecto.UUID.generate(),
          display_name: "DM Dup",
          role: "member"
        })

      {:ok, dm1} = Channels.create_dm(prefix, [profile.id, profile2.id])
      {:ok, dm2} = Channels.create_dm(prefix, [profile2.id, profile.id])

      assert dm1.id == dm2.id
    end

    test "creates group_dm for 3+ profiles", %{prefix: prefix, profile: profile} do
      {:ok, p2} =
        Profile.create(prefix, %{
          account_id: Ecto.UUID.generate(),
          display_name: "Group 2",
          role: "member"
        })

      {:ok, p3} =
        Profile.create(prefix, %{
          account_id: Ecto.UUID.generate(),
          display_name: "Group 3",
          role: "member"
        })

      {:ok, dm} = Channels.create_dm(prefix, [profile.id, p2.id, p3.id])
      assert dm.kind == "group_dm"
    end
  end

  describe "add_members/3" do
    test "adds members to a channel", %{prefix: prefix, profile: profile} do
      {:ok, channel} =
        Channels.create_channel(prefix, %{
          name: "Add Members Test",
          created_by: profile.id
        })

      {:ok, p2} =
        Profile.create(prefix, %{
          account_id: Ecto.UUID.generate(),
          display_name: "Member 2",
          role: "member"
        })

      {:ok, p3} =
        Profile.create(prefix, %{
          account_id: Ecto.UUID.generate(),
          display_name: "Member 3",
          role: "member"
        })

      {:ok, count} = Channels.add_members(prefix, channel.id, [p2.id, p3.id])
      assert count == 2

      members = Channels.list_members(prefix, channel.id)
      member_ids = Enum.map(members, & &1.profile_id)
      assert p2.id in member_ids
      assert p3.id in member_ids
    end

    test "skips duplicate members", %{prefix: prefix, profile: profile} do
      {:ok, channel} =
        Channels.create_channel(prefix, %{
          name: "Dup Members",
          created_by: profile.id
        })

      {:ok, p2} =
        Profile.create(prefix, %{
          account_id: Ecto.UUID.generate(),
          display_name: "Dup Member",
          role: "member"
        })

      {:ok, 1} = Channels.add_members(prefix, channel.id, [p2.id])
      # Adding the same member again should skip
      {:ok, 0} = Channels.add_members(prefix, channel.id, [p2.id])
    end
  end

  describe "update_topic/3" do
    test "updates channel topic", %{prefix: prefix, profile: profile} do
      {:ok, channel} =
        Channels.create_channel(prefix, %{
          name: "Topic Test",
          created_by: profile.id
        })

      {:ok, updated} = Channels.update_topic(prefix, channel.id, "New topic here")
      assert updated.topic == "New topic here"
    end

    test "returns error for non-existent channel", %{prefix: prefix} do
      assert {:error, :not_found} =
               Channels.update_topic(prefix, Ecto.UUID.generate(), "No channel")
    end
  end
end
