defmodule EdgeRouter.MainProxy do
  use MainProxy.Proxy

  @main_domain ".msgr.no"

  def main_domain() do
    "." <> System.get_env("PHX_HOST") || @main_domain
  end

  @impl MainProxy.Proxy
  def backends do
    [
      %{
        domain: "msgr" <> main_domain(),
        phoenix_endpoint: MessngrWeb.Endpoint
      },
      %{
        domain: "auth" <> main_domain(),
        phoenix_endpoint: AuthProvider.Endpoint
      },
      %{
        domain: "teams" <> main_domain(),
        phoenix_endpoint: TeamsWeb.Endpoint
      },
      %{
        domain: "*.teams" <> main_domain(),
        phoenix_endpoint: TeamsWeb.Endpoint,
        wildcard: true
      },
      %{
        domain: "teams-slackapi" <> main_domain(),
        phoenix_endpoint: SlackApiWeb.Endpoint
      },
      %{
        verb: ~r/get/i,
        path: ~r{^/main-proxy-plug-test$},
        plug: MainProxy.Plug.Test,
        opts: [1, 2, 3]
      }
    ]
  end


end
