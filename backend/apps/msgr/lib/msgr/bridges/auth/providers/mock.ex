defmodule Messngr.Bridges.Auth.Providers.Mock do
  @moduledoc """
  Mock OAuth provider used in development and test environments.

  The provider immediately redirects back to the callback endpoint with a
  generated authorization code and returns synthetic tokens when the callback is
  invoked. This keeps the flow deterministic without relying on external
  services.
  """

  @behaviour Messngr.Bridges.Auth.OAuthProvider

  alias Messngr.Bridges.AuthSession

  @impl true
  def authorization_url(%AuthSession{} = _session, state, opts) do
    callback_path = Keyword.fetch!(opts, :callback_path)
    code_challenge = Keyword.get(opts, :code_challenge)

    code =
      :crypto.strong_rand_bytes(12)
      |> Base.url_encode64(padding: false)

    url =
      callback_path
      |> URI.parse()
      |> Map.put(:query, URI.encode_query(%{"code" => code, "state" => state, "cc" => code_challenge}))
      |> URI.to_string()

    {:ok, url, %{code: code}}
  end

  @impl true
  def exchange_code(%AuthSession{} = _session, code, opts) do
    verifier = Keyword.get(opts, :code_verifier)

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {:ok,
     %{
       "access_token" => "mock-access-#{code}",
       "refresh_token" => "mock-refresh-#{code}",
       "token_type" => "Bearer",
       "expires_at" => DateTime.to_iso8601(DateTime.add(now, 3600, :second)),
       "code_verifier" => verifier
     }}
  end
end
