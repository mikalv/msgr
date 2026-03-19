# Seeds a test team with tenant schema, a couple of profiles,
# a #general channel, and some sample messages.
#
# Usage:
#   mix run apps/teams/priv/repo/seeds_tenant_test.exs
#
# Requires the Messngr.Repo (msgr app) to be started so we can
# create the team in the public schema, then the tenant schema.

alias Messngr.Repo, as: PubRepo
alias Messngr.Teams.Team
alias Messngr.Teams.TeamMembership
alias Messngr.Accounts.Account
alias Messngr.Tenancy

alias Teams.TenantModels.{Profile, Channel, ChannelMembership, Message}

IO.puts("=== Tenant Test Seed ===")

# 1. Create two test accounts in public schema (if they don't exist)
{:ok, alice} =
  case PubRepo.get_by(Account, email: "alice@test.local") do
    nil ->
      %Account{}
      |> Account.changeset(%{
        email: "alice@test.local",
        display_name: "Alice Testersen",
        handle: "alice"
      })
      |> PubRepo.insert()

    existing ->
      {:ok, existing}
  end

{:ok, bob} =
  case PubRepo.get_by(Account, email: "bob@test.local") do
    nil ->
      %Account{}
      |> Account.changeset(%{
        email: "bob@test.local",
        display_name: "Bob Utvikler",
        handle: "bob"
      })
      |> PubRepo.insert()

    existing ->
      {:ok, existing}
  end

IO.puts("Accounts: alice=#{alice.id}, bob=#{bob.id}")

# 2. Create a team in public schema
team_id = Ecto.UUID.generate()

{:ok, team} =
  case PubRepo.get_by(Team, slug: "testteam") do
    nil ->
      %Team{}
      |> Team.changeset(%{
        id: team_id,
        name: "Test Team",
        slug: "testteam",
        schema_name: "tenant_#{team_id}",
        domain: "testteam.dev.msgr.no",
        owner_account_id: alice.id
      })
      |> PubRepo.insert()

    existing ->
      {:ok, existing}
  end

IO.puts("Team: #{team.slug} (#{team.id}), schema: #{team.schema_name}")

# 3. Create tenant schema and run migrations
schema = Tenancy.create_tenant(team.id)
IO.puts("Tenant schema created: #{schema}")

prefix = team.schema_name

# 4. Add team memberships (public)
for {account, role} <- [{alice, "owner"}, {bob, "member"}] do
  %TeamMembership{}
  |> TeamMembership.changeset(%{account_id: account.id, team_id: team.id, role: role})
  |> PubRepo.insert(on_conflict: :nothing, conflict_target: [:account_id, :team_id])
end

# 5. Create profiles in tenant schema
{:ok, alice_profile} = Profile.create(prefix, %{account_id: alice.id, display_name: "Alice", role: "owner"})
{:ok, bob_profile} = Profile.create(prefix, %{account_id: bob.id, display_name: "Bob", role: "member"})

IO.puts("Profiles: alice=#{alice_profile.id}, bob=#{bob_profile.id}")

# 6. Create #general channel
{:ok, general} =
  Channel.create(prefix, %{
    name: "General",
    slug: "general",
    kind: "channel",
    visibility: "public",
    topic: "General discussion",
    created_by: alice_profile.id
  })

IO.puts("Channel: ##{general.slug} (#{general.id})")

# 7. Add both profiles to #general
for profile <- [alice_profile, bob_profile] do
  ChannelMembership.join(prefix, %{channel_id: general.id, profile_id: profile.id})
end

# 8. Post some messages
{:ok, m1} =
  Message.create(prefix, %{
    channel_id: general.id,
    sender_profile_id: alice_profile.id,
    content: %{"text" => "Velkommen til #general!"}
  })

{:ok, m2} =
  Message.create(prefix, %{
    channel_id: general.id,
    sender_profile_id: bob_profile.id,
    content: %{"text" => "Takk! Klar for testing."}
  })

# Thread reply
{:ok, _m3} =
  Message.create(prefix, %{
    channel_id: general.id,
    sender_profile_id: alice_profile.id,
    thread_parent_id: m1.id,
    content: %{"text" => "Denne meldingen er i en trad."}
  })

IO.puts("Messages seeded: #{m1.id}, #{m2.id} + 1 thread reply")
IO.puts("=== Seed complete ===")
