defmodule TeamsWeb.ChannelCase do
  @moduledoc """
  This module defines the test case to be used by channel tests.

  Teams.Repo does not use the SQL Sandbox in test — see `Teams.DataCase`.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      import Phoenix.ChannelTest
      import TeamsWeb.ChannelCase

      @endpoint TeamsWeb.Endpoint
    end
  end

  setup _tags do
    :ok
  end
end
