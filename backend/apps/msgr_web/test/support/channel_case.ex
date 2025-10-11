defmodule MessngrWeb.ChannelCase do
  @moduledoc """
  This module defines the test case to be used by
  channel tests.

  Such tests rely on `Phoenix.ChannelTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use MessngrWeb.ChannelCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with channels
      import Phoenix.ChannelTest
      import MessngrWeb.ChannelCase
      import Messngr.Noise.SessionFixtures

      # The default endpoint for testing
      @endpoint MessngrWeb.Endpoint
    end
  end

  setup tags do
    Messngr.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Assigns Noise actor metadata to a socket so channel joins can rely on the same
  assigns that `MessngrWeb.UserSocket.connect/3` would normally populate.
  Returns `{socket, session_info}`.
  """
  def attach_noise_socket(socket, account, profile, attrs \\ %{}) do
    session_info = noise_session_fixture(account, profile, attrs)

    socket =
      socket
      |> Phoenix.Socket.assign(:current_account, account)
      |> Phoenix.Socket.assign(:current_profile, profile)
      |> Phoenix.Socket.assign(:current_device, session_info.device)
      |> Phoenix.Socket.assign(:noise_session_token, session_info.token)
      |> Phoenix.Socket.assign(:noise_session, session_info.session)

    {socket, session_info}
  end
end
