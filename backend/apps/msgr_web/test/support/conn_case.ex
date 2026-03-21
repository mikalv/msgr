defmodule MessngrWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use MessngrWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  alias Messngr.Noise.SessionFixtures

  using do
    quote do
      # The default endpoint for testing
      @endpoint MessngrWeb.Endpoint

      use MessngrWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import MessngrWeb.ConnCase
      import Messngr.Noise.SessionFixtures
    end
  end

  setup tags do
    Messngr.DataCase.setup_sandbox(tags)

    # Teams.Repo shares the same database; sandbox it so tenant operations
    # are rolled back after each test.
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Teams.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Issues a Noise session token for the given account/profile and attaches it to the connection.
  Returns a tuple `{conn, session_info}` where `session_info` contains the issued
  token and device fixture.
  """
  def attach_noise_session(conn, account, profile, attrs \\ %{}) do
    session_info = SessionFixtures.noise_session_fixture(account, profile, attrs)
    conn = Plug.Conn.put_req_header(conn, "authorization", "Noise #{session_info.token}")
    {conn, session_info}
  end

  @doc """
  Issues a JWT access token for the given account/profile and attaches it to the
  connection as a Bearer token. Returns the conn with the Authorization header set.
  """
  def attach_jwt_session(conn, account, profile) do
    resource = %{id: account.id}

    custom_claims = %{
      "pid" => profile.id,
      "ten" => %{},
      "hdl" => account.handle || account.display_name
    }

    {:ok, access_token, _claims} =
      AuthProvider.Guardian.encode_and_sign(
        resource,
        custom_claims,
        token_type: "access",
        ttl: {15, :minute}
      )

    Plug.Conn.put_req_header(conn, "authorization", "Bearer #{access_token}")
  end

  @doc """
  Creates an account, a team (with tenant schema), and a team profile.
  Returns a map with :account, :profile, :team, :team_profile, :conn (authenticated),
  and :prefix (the tenant schema name).
  """
  def setup_team(conn) do
    {:ok, account} = Messngr.Accounts.create_account(%{"display_name" => "Team Tester"})
    profile = hd(account.profiles)
    conn = attach_jwt_session(conn, account, profile)

    slug = "test-team-#{System.unique_integer([:positive])}"

    create_conn = Phoenix.ConnTest.post(conn, "/api/teams", %{name: "Test Team", slug: slug})
    %{"data" => %{"id" => team_id}} = Phoenix.ConnTest.json_response(create_conn, 201)

    team = Teams.Repo.get!(Teams.Schemas.Team, team_id)
    team_profile = Teams.TeamManagement.get_profile_for_account(team.schema_name, account.id)

    %{
      account: account,
      profile: profile,
      team: team,
      team_profile: team_profile,
      conn: conn,
      prefix: team.schema_name,
      slug: slug
    }
  end
end
