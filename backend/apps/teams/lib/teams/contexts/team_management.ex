defmodule Teams.TeamManagement do
  @moduledoc """
  Context module for team management.

  Handles team creation (with tenant schema provisioning),
  membership, and team listing.
  """

  alias Teams.Repo
  alias Teams.Schemas.{Team, TeamMembership}
  alias Teams.Tenancy
  alias Teams.TenantModels.{Profile, Channel, ChannelMembership}

  import Ecto.Query

  # ── Team CRUD ──────────────────────────────────────────────

  @doc """
  Creates a new team, provisions a tenant schema, and seeds a #general channel.

  The `attrs` map should include:
    * `:name` — team display name
    * `:slug` — URL-safe slug
    * `:owner_account_id` — account id of the creator

  Returns `{:ok, team}` or `{:error, changeset}`.
  """
  def create_team(attrs) do
    team_id = Ecto.UUID.generate()
    schema_name = Tenancy.prefix(team_id)

    # 1. Create tenant schema + run migrations OUTSIDE transaction
    #    (CREATE SCHEMA and migrations need their own connections)
    Tenancy.create_tenant(team_id)

    # 2. Insert team record and seed data inside a transaction
    Repo.transaction(fn ->
      team_attrs =
        attrs
        |> Map.put(:id, team_id)
        |> Map.put(:schema_name, schema_name)

      team =
        %Team{}
        |> Team.changeset(team_attrs)
        |> Repo.insert!()

      # 3. Create owner membership
      %TeamMembership{}
      |> TeamMembership.changeset(%{
        account_id: team.owner_account_id,
        team_id: team.id,
        role: "owner",
        joined_at: DateTime.utc_now()
      })
      |> Repo.insert!()

      # 4. Create owner profile in tenant (with display_name from account)
      owner_display_name = resolve_account_display_name(team.owner_account_id)

      {:ok, owner_profile} =
        Profile.create(schema_name, %{
          account_id: team.owner_account_id,
          display_name: owner_display_name,
          role: "owner"
        })

      # 5. Seed #general channel
      {:ok, general} =
        Channel.create(schema_name, %{
          name: "general",
          slug: "general",
          kind: "channel",
          visibility: "public",
          created_by: owner_profile.id
        })

      # 6. Add owner to #general
      ChannelMembership.join(schema_name, %{
        channel_id: general.id,
        profile_id: owner_profile.id,
        role: "admin"
      })

      team
    end)
  end

  @doc """
  Gets a team by slug. Raises Ecto.NoResultsError if not found.
  """
  def get_team_by_slug!(slug) do
    Repo.get_by!(Team, slug: slug)
  end

  @doc """
  Gets a team by slug. Returns nil if not found.
  """
  def get_team_by_slug(slug) do
    Repo.get_by(Team, slug: slug)
  end

  # ── Membership ─────────────────────────────────────────────

  @doc """
  Joins an account to a team.
  Creates a TeamMembership in the public schema and a Profile in the tenant schema.
  Adds the new member to the #general channel.
  """
  def join_team(team, account_id, attrs \\ %{}) do
    Repo.transaction(fn ->
      # 1. Create public membership
      membership =
        %TeamMembership{}
        |> TeamMembership.changeset(%{
          account_id: account_id,
          team_id: team.id,
          role: Map.get(attrs, :role, "member"),
          joined_at: DateTime.utc_now()
        })
        |> Repo.insert!()

      prefix = team.schema_name

      # 2. Create tenant profile (fallback to account display_name if not provided)
      display_name =
        case Map.get(attrs, :display_name) do
          nil -> resolve_account_display_name(account_id)
          "" -> resolve_account_display_name(account_id)
          name -> name
        end

      {:ok, profile} =
        Profile.create(prefix, %{
          account_id: account_id,
          display_name: display_name,
          role: "member"
        })

      # 3. Add to #general channel
      case Channel.get_by_slug(prefix, "general") do
        nil -> :ok
        general ->
          ChannelMembership.join(prefix, %{
            channel_id: general.id,
            profile_id: profile.id
          })
      end

      %{membership: membership, profile: profile}
    end)
  end

  @doc """
  Lists all teams an account belongs to.
  """
  def list_teams_for_account(account_id) do
    from(tm in TeamMembership,
      where: tm.account_id == ^account_id,
      join: t in Team,
      on: t.id == tm.team_id,
      select: t,
      order_by: [desc: tm.joined_at]
    )
    |> Repo.all()
  end

  @doc """
  Checks if an account is a member of a team.
  """
  def member?(team_id, account_id) do
    from(tm in TeamMembership,
      where: tm.team_id == ^team_id and tm.account_id == ^account_id
    )
    |> Repo.exists?()
  end

  @doc "Get a membership record for an account in a team."
  def get_membership(team_id, account_id) do
    Repo.get_by(TeamMembership, team_id: team_id, account_id: account_id)
  end

  @doc """
  Gets the profile for an account within a team's tenant schema.
  """
  def get_profile_for_account(prefix, account_id) do
    Profile.get_by_account_id(prefix, account_id)
  end

  # Resolves a display_name from the global account record.
  # Falls back through display_name -> handle -> email -> "Ukjent".
  defp resolve_account_display_name(account_id) do
    try do
      account = Messngr.Accounts.get_account!(account_id)
      account.display_name || account.handle || account.email || "Ukjent"
    rescue
      Ecto.NoResultsError -> "Ukjent"
    end
  end
end
