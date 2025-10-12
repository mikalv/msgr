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
end
