defmodule Messngr.Noise.SessionFixtures do
  @moduledoc """
  Test helpers for Noise sessions.

  Noise transport is handled by the Rust gateway in production; these fixtures
  provide lightweight stubs so ConnCase and legacy Noise tests can compile.
  """

  @doc """
  Returns a map with a stub Noise session token and device metadata.
  """
  def noise_session_fixture(account, profile, attrs \\ %{}) do
    device =
      Map.get(attrs, :device) ||
        %{
          id: Map.get(attrs, :device_id) || Ecto.UUID.generate(),
          account_id: account.id,
          enabled: true,
          device_public_key:
            Map.get(attrs, :device_public_key) ||
              Base.encode64(:crypto.strong_rand_bytes(32))
        }

    %{
      token:
        Map.get(attrs, :token) ||
          ("noise-test-" <> Base.encode16(:crypto.strong_rand_bytes(16), case: :lower)),
      device: device,
      account: account,
      profile: profile,
      session_id: Map.get(attrs, :session_id) || Ecto.UUID.generate()
    }
  end
end
