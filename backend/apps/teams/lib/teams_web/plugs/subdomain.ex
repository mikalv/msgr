defmodule TeamsWeb.Plugs.Subdomain do
  @behaviour Plug
  require Logger
  import Plug.Conn, only: [put_private: 3, halt: 1]

  # we will use the options parameter and merge the incoming options with the existing one
  def init(opts) do
    conf = Application.get_env(:teams, TeamsWeb.Endpoint)
    Map.merge(
      opts,
      %{ root_host: conf[:url][:host] }
    )
  end

# unpack subdomain_router argument
  def call(%Plug.Conn{host: host} = conn, %{root_host: root_host, subdomain_router: router} = _opts) do
    check_team_plug = TeamsWeb.Plugs.ExistingTeam
    case extract_subdomain(host, root_host) do
      subdomain when byte_size(subdomain) > 0 ->
        Logger.info "Subdomain: #{subdomain}"
        put_private(conn, :subdomain, subdomain)
        |> check_team_plug.call(%{})
        |> router.call(router.init({})) # <--- call the router with the incoming connection
        |> halt() # <--- halt further execution
      _ ->
        conn
    end
  end

  defp extract_subdomain(host, root_host) do
    String.replace(host, ~r/.?#{root_host}/, "")
  end
end
