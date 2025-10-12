defmodule MessngrWeb.Router do
  use MessngrWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :actor do
    plug MessngrWeb.Plugs.CurrentActor
  end

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {MessngrWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  scope "/api", MessngrWeb do
    pipe_through :api

    post "/auth/challenge", AuthController, :challenge
    post "/auth/verify", AuthController, :verify
    post "/auth/oidc", AuthController, :oidc
    resources "/users", AccountController, only: [:index, :create]
  end

  scope "/api", MessngrWeb do
    pipe_through [:api, :actor]

    get "/conversations", ConversationController, :index
    post "/conversations", ConversationController, :create
    post "/conversations/:id/uploads", MediaUploadController, :create
    get "/conversations/:id/messages", MessageController, :index
    post "/conversations/:id/messages", MessageController, :create
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
