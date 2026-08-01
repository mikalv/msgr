defmodule MessngrWeb.UserSocketTest do
  use MessngrWeb.ChannelCase

  alias Messngr.Accounts
  alias MessngrWeb.UserSocket

  test "connect assigns actor from noise_session param" do
    {:ok, account} = Accounts.create_account(%{"display_name" => "Socket"})
    profile = hd(account.profiles)
    %{token: token} = noise_session_fixture(account, profile)

    base_socket = socket(UserSocket, "user", %{})

    assert {:ok, socket} = UserSocket.connect(%{"noise_session" => token}, base_socket, %{})
    assert socket.assigns.current_profile.id == profile.id
    assert socket.assigns.current_account.id == account.id
    assert socket.assigns.noise_session_token == token
  end

  test "connect reads token from session info" do
    {:ok, account} = Accounts.create_account(%{"display_name" => "Session"})
    profile = hd(account.profiles)
    %{token: token} = noise_session_fixture(account, profile)

    base_socket = socket(UserSocket, "user", %{})
    connect_info = %{session: %{"noise_session_token" => token}}

    assert {:ok, socket} = UserSocket.connect(%{}, base_socket, connect_info)
    assert socket.assigns.current_profile.id == profile.id
  end

  test "connect without token fails" do
    base_socket = socket(UserSocket, "user", %{})
    assert :error = UserSocket.connect(%{}, base_socket, %{})
  end
end
