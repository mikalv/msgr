defmodule TeamsWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by tests that require setting up
  a connection.

  Teams.Repo does not use the SQL Sandbox in test — see `Teams.DataCase`.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint TeamsWeb.Endpoint

      use TeamsWeb, :verified_routes

      import Plug.Conn
      import Phoenix.ConnTest
      import TeamsWeb.ConnCase
    end
  end

  setup _tags do
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
