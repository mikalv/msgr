defmodule Messngr.Noise.SessionFixtures do
  @moduledoc """
  Helpers for issuing Noise session tokens in tests without going through the
  full handshake.
  """

  alias Messngr.Accounts
  alias Messngr.Noise.SessionStore
  alias Messngr.Transport.Noise.Session

  def noise_device_fixture(account, profile, attrs \\ %{}) do
    key = Map.get(attrs, :device_public_key) || Map.get(attrs, "device_public_key") || "noise-#{System.unique_integer([:positive])}"

    {:ok, device} =
      Accounts.create_device(%{
        account_id: account.id,
        profile_id: profile && profile.id,
        device_public_key: key
      })

    device
  end

  def noise_session_fixture(account, profile, attrs \\ %{}) do
    device =
      attrs
      |> Map.get(:device)
      |> Kernel.||(Map.get(attrs, "device"))
      |> Kernel.||(noise_device_fixture(account, profile, attrs))

    actor = %{
      account_id: account.id,
      profile_id: profile.id,
      device_id: device.id,
      device_public_key: device.device_public_key
    }

    {:ok, session} = SessionStore.issue(actor)

    %{
      session: session,
      device: device,
      token: SessionStore.encode_token(Session.token(session))
    }
  end
end
