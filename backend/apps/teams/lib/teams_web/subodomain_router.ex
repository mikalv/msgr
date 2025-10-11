defmodule TeamsWeb.SubdomainRouter do
  use TeamsWeb, :router
  #
  # This module is the router for every teams subdomain.
  # Every path reuqires conn.private[:subdomain] to be set.
  #

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

  pipeline :authorized_api do
    plug TeamsWeb.Plugs.PartOfTeam
  end

  pipeline :graphql do
    plug TeamsWeb.GraphQL.Context
  end

  scope "/", TeamsWeb.Subdomain do
    pipe_through :browser

    get "/", PageController, :home
    get "/router_test", PageController, :router_test
  end

  scope "/v1/api", TeamsWeb.Subdomain do
    pipe_through [:api, :authed_api]
    # Users must be allowed to create a profile, to be a part of the team.
    # So this path needs only authentication and not authorization.
    post "/profiles", ProfileController, :create
  end

  scope "/v1/api", TeamsWeb.Subdomain do
    pipe_through [:api, :authed_api, :authorized_api]
    get "/rooms", RoomsController, :list
    post "/rooms", RoomsController, :create
    put "/rooms/:room_id", RoomsController, :update
    get "/rooms/:room_id", RoomsController, :get
    delete "/rooms/:room_id", RoomsController, :delete
    get "/rooms/:room_id/history", RoomsController, :history

    get "/profiles", ProfileController, :list
    put "/profiles/:profile_id", ProfileController, :update
    get "/profiles/:profile_id", ProfileController, :get
    delete "/profiles/:profile_id", ProfileController, :delete

    get "/conversations", ConversationsController, :list
    post "/conversations", ConversationsController, :create
    put "/conversations/:conversation_id", ConversationsController, :update
    get "/conversations/:conversation_id", ConversationsController, :get
    delete "/conversations/:conversation_id", ConversationsController, :delete
    get "/conversations/:conversation_id/history", ConversationsController, :history

    get "/messages", MessageController, :list
    post "/messages", MessageController, :create
    put "/messages/:message_id", MessageController, :update
    get "/messages/:message_id", MessageController, :get
    delete "/messages/:message_id", MessageController, :delete
  end

  scope "/v2/api", TeamsWeb.Subdomain do
    pipe_through [:api, :authed_api, :authorized_api, :graphql]
    forward "/graphql", Absinthe.Plug,
      schema: TeamsWeb.GraphQL.Schema,
      analyze_complexity: true,
      max_complexity: 100
  end

  scope "/v2/api" do
    forward "/graphiql", Absinthe.Plug.GraphiQL,
      schema: TeamsWeb.GraphQL.Schema
  end

end
