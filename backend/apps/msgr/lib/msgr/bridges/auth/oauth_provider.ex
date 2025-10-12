defmodule Messngr.Bridges.Auth.OAuthProvider do
  @moduledoc """
  Behaviour describing the minimum contract required for bridge OAuth providers.
  """

  alias Messngr.Bridges.AuthSession

  @callback authorization_url(AuthSession.t(), String.t(), keyword()) ::
              {:ok, String.t(), map()} | {:error, term()}

  @callback exchange_code(AuthSession.t(), String.t(), keyword()) ::
              {:ok, map()} | {:error, term()}
end
