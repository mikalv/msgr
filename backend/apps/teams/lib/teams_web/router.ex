defmodule TeamsWeb.Router do
  use TeamsWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {TeamsWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :authed_api do
    plug TeamsWeb.Plugs.AuthPipeline
  end

  scope "/", TeamsWeb do
    pipe_through :browser

    get "/", PageController, :home
    post "/create_team", PageController, :create_team
  end

  # Other scopes may use custom stacks.
  scope "/public/v1/api", TeamsWeb do
    pipe_through [:api, :authed_api]

    post "/select/team/:team_name", PublicApiController, :select_team
    get "/teams", PublicApiController, :my_teams
    post "/teams", PublicApiController, :create_team
    put "/teams/:team_id", PublicApiController, :update_team
    get "/teams/:team_id", PublicApiController, :get_team
    get "/teams/:team_id", PublicApiController, :delete_team
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:teams, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard",
          metrics: TeamsWeb.Telemetry,
          ecto_repos: [Teams.Repo, Messngr.Repo, AuthProvider.Repo],
          ecto_psql_extras_options: [long_running_queries: [threshold: "200 milliseconds"]]
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
