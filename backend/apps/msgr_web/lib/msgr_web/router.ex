defmodule MessngrWeb.Router do
  use MessngrWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :actor do
    plug MessngrWeb.Plugs.CurrentActor
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

    post "/conversations", ConversationController, :create
    get "/conversations/:id/messages", MessageController, :index
    post "/conversations/:id/messages", MessageController, :create

    resources "/families", FamilyController, only: [:index, :create, :show] do
      resources "/events", FamilyEventController, only: [:index, :create, :show, :update, :delete]

      resources "/shopping_lists", FamilyShoppingListController,
        only: [:index, :create, :show, :update, :delete] do
        resources "/items", FamilyShoppingItemController, only: [:index, :create, :update, :delete]
      end

      resources "/todo_lists", FamilyTodoListController, only: [:index, :create, :show, :update, :delete] do
        resources "/items", FamilyTodoItemController, only: [:index, :create, :update, :delete]
      end
    end
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
