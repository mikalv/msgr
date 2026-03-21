defmodule MessngrWeb.Router do
  use MessngrWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :actor do
    plug MessngrWeb.Plugs.CurrentActor, authorization_schemes: [:noise]
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {MessngrWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  # Health and Metrics endpoints (no authentication required)
  scope "/", MessngrWeb do
    get "/health", HealthController, :health
    get "/metrics", HealthController, :metrics
  end

  scope "/api", MessngrWeb do
    pipe_through :api

    post "/v1/auth/challenge", AuthController, :challenge
    post "/v1/auth/verify", AuthController, :verify
    post "/v1/auth/oidc", AuthController, :oidc
    # Noise handshake is now handled by Rust Gateway
    resources "/users", AccountController, only: [:index, :create, :update]
  end

  scope "/api", MessngrWeb do
    pipe_through [:api, :actor]

    get "/conversations", ConversationController, :index
    post "/conversations", ConversationController, :create
    patch "/conversations/:id", ConversationController, :update
    post "/conversations/:id/uploads", MediaUploadController, :create
    get "/conversations/:id/messages", MessageController, :index
    post "/conversations/:id/messages", MessageController, :create
    post "/conversations/:id/messages/:message_id/delivery", MessageController, :deliver
    post "/conversations/:id/watch", ConversationController, :watch
    delete "/conversations/:id/watch", ConversationController, :unwatch
    get "/conversations/:id/watchers", ConversationController, :watchers

    resources "/families", FamilyController, only: [:index, :create, :show] do
      resources "/events", FamilyEventController, only: [:index, :create, :show, :update, :delete]

      resources "/shopping_lists", FamilyShoppingListController,
        only: [:index, :create, :show, :update, :delete] do
        resources "/items", FamilyShoppingItemController, only: [:index, :create, :update, :delete]
      end

      resources "/todo_lists", FamilyTodoListController, only: [:index, :create, :show, :update, :delete] do
        resources "/items", FamilyTodoItemController, only: [:index, :create, :update, :delete]
      end

      resources "/notes", FamilyNoteController, only: [:index, :create, :show, :update, :delete]
    end
    post "/conversations/:id/assistant", AIController, :conversation_reply
    post "/contacts/import", ContactController, :import
    post "/contacts/lookup", ContactController, :lookup
    post "/ai/chat", AIController, :chat
    post "/ai/summarize", AIController, :summarize
    post "/ai/run", AIController, :run
    get "/bridges/catalog", BridgeCatalogController, :index
    post "/bridges/:bridge_id/sessions", BridgeAuthSessionController, :create
    get "/bridges/sessions/:id", BridgeAuthSessionController, :show
    post "/bridges/:bridge_id/sessions/:id/credentials", BridgeAuthSessionController, :submit_credentials
    delete "/bridges/:bridge_id", BridgeAccountController, :delete
    get "/account/me", AccountController, :me
    resources "/profiles", ProfileController, only: [:index, :create, :update, :delete]
    post "/profiles/:id/switch", ProfileController, :switch
  end

  # ── Team API (multi-tenant Slack-like) ──────────────────────

  pipeline :tenant do
    plug MessngrWeb.Plugs.TenantFromSlug
  end

  # Endpoints scoped to a team via :slug → tenant resolution
  scope "/api/teams/:slug", MessngrWeb do
    pipe_through [:api, :actor, :tenant]

    get "/channels", TeamChannelController, :index
    post "/channels", TeamChannelController, :create
    post "/channels/:channel_id/members", TeamChannelController, :add_members
    get "/channels/:channel_id/messages", TeamMessageController, :index
    post "/channels/:channel_id/messages", TeamMessageController, :create
    post "/channels/:channel_id/messages/:message_id/reactions", TeamReactionController, :toggle
    get "/channels/:channel_id/threads/:message_id", TeamMessageController, :thread
    put "/channels/:channel_id/read_cursor", TeamReadCursorController, :update
    get "/profiles", TeamProfileController, :index
    put "/profiles/me", TeamProfileController, :update
    post "/media/presign", TeamMediaController, :presign
    post "/dms", TeamDmController, :create
  end

  # Team-level endpoints (no tenant resolution needed)
  scope "/api/teams", MessngrWeb do
    pipe_through [:api, :actor]

    get "/", TeamController, :index
    post "/", TeamController, :create
    post "/:slug/join", TeamController, :join
  end

  scope "/auth/bridge", MessngrWeb do
    pipe_through :browser

    get "/:session_id/start", BridgeAuthBrowserController, :start
    get "/:session_id/callback", BridgeAuthBrowserController, :callback
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

      live_dashboard "/dashboard", metrics: MessngrWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
