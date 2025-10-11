defmodule AuthProvider.Plug.BasicAuth do
  @moduledoc """
  Plug to authenticate requests using basic auth.
  """
  @realm "Area 51"

  require Logger

  def init(opts) do
    username = Keyword.fetch!(opts, :username) |> get_value!()
    password = Keyword.fetch!(opts, :password) |> get_value!()

    %{username: username, password: password}
  end

  def call(conn, %{username: username, password: password}) do
    Logger.info("Basic auth: #{username}:#{password}")
    Plug.BasicAuth.basic_auth(conn, username: username, password: password, realm: @realm)
  end

  defp get_value!({:system, value_name}) do
    System.get_env(value_name)
  end
end
