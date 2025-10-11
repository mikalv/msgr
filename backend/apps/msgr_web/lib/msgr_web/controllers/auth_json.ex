defmodule MessngrWeb.AuthJSON do
  alias Messngr.Auth.Challenge

  def challenge(%{challenge: %Challenge{} = challenge, code: code, target_hint: hint}) do
    base = %{
      id: challenge.id,
      channel: challenge.channel,
      expires_at: challenge.expires_at,
      target_hint: hint
    }

    if is_binary(code) do
      Map.put(base, :debug_code, code)
    else
      base
    end
  end

  def session(%{result: %{account: account, identity: identity} = result}) do
    base = %{
      account: %{
        id: account.id,
        display_name: account.display_name,
        email: account.email,
        phone_number: account.phone_number
      },
      identity: %{
        id: identity.id,
        kind: identity.kind,
        verified_at: identity.verified_at
      }
    }

    maybe_put_noise_session(base, Map.get(result, :noise_session))
  end

  defp maybe_put_noise_session(map, nil), do: map

  defp maybe_put_noise_session(map, %{id: id, token: token}) do
    Map.put(map, :noise_session, %{id: id, token: token})
  end
end
