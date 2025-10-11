defmodule AuthProvider.Router do
  use AuthProvider, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {AuthProvider.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :ensure_auth do
    plug Guardian.Plug.EnsureAuthenticated
  end

  scope "/", AuthProvider do
    pipe_through :browser

    get "/", PageController, :home
  end

  # Other scopes may use custom stacks.
  scope "/api", AuthProvider do
    pipe_through :api

    post "/v1/device/register", ApiController, :device_register
    post "/v1/device/context", ApiController, :device_context
    post "/v1/login", ApiController, :login
    post "/v1/login/code", ApiController, :login_code
    post "/v1/refresh_token", ApiController, :refresh_token

    scope "/xmppAuth" do
      get "check_password", ApiController, :check_password
      get "user_exists", ApiController, :user_exists
    end
  end

  scope "/oauth", AuthProvider.Oauth do
    pipe_through :api

    post "/revoke", RevokeController, :revoke
    post "/token", TokenController, :token
    post "/introspect", IntrospectController, :introspect
  end


  scope "/openid", AuthProvider.Openid do
    pipe_through [:api]

    get "/userinfo", UserinfoController, :userinfo
    post "/userinfo", UserinfoController, :userinfo
    get "/jwks", JwksController, :jwks_index
  end

  ####

  scope "/oauth", AuthProvider.Oauth do
    pipe_through [:browser, :fetch_current_user]

    get "/oauth_authorize", AuthorizeController, :authorize
  end

  scope "/openid", AuthProvider.Openid do
    pipe_through [:browser, :fetch_current_user]

    get "/authorize", AuthorizeController, :authorize
  end

  def fetch_current_user(conn, opts \\ []) do
    conn
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:msgr_web, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: AuthProvider.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
