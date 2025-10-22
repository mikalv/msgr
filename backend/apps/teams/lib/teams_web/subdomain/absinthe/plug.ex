defmodule TeamsWeb.Subdomain.Absinthe.Plug do
  @moduledoc """
  Thin wrapper around `Absinthe.Plug` used within the subdomain router scopes.
  """

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, opts) do
    Absinthe.Plug.call(conn, Absinthe.Plug.init(opts))
  end
end
