defmodule MessngrWeb.DeviceChannelTest do
  use MessngrWeb.ChannelCase

  alias Messngr.Accounts

  setup do
    {:ok, account} = Accounts.create_account(%{"display_name" => "Device Owner"})
    profile = hd(account.profiles)

    {socket, _session} =
      MessngrWeb.UserSocket
      |> socket("user_id", %{some: :assign})
      |> attach_noise_socket(account, profile)

    {:ok, _, socket} = subscribe_and_join(socket, MessngrWeb.DeviceChannel, "device:lobby")

    %{socket: socket}
  end

  test "ping replies with status ok", %{socket: socket} do
    ref = push(socket, "ping", %{"hello" => "there"})
    assert_reply ref, :ok, %{"hello" => "there"}
  end

  test "shout broadcasts to device:lobby", %{socket: socket} do
    push(socket, "shout", %{"hello" => "all"})
    assert_broadcast "shout", %{"hello" => "all"}
  end

  test "broadcasts are pushed to the client", %{socket: socket} do
    broadcast_from!(socket, "broadcast", %{"some" => "data"})
    assert_push "broadcast", %{"some" => "data"}
  end
end
