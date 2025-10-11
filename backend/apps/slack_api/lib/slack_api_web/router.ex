defmodule SlackApiWeb.Router do
  use SlackApiWeb, :router

  alias SlackApiWeb.Controllers.{
    ApiController,
    ChatApiController,
    ConversationsApiController,
    ReactionsApiController,
    RemindersApiController,
    UsersApiController
  }

  pipeline :api do
    plug :accepts, ["json"]
    plug SlackApiWeb.Plugs.CurrentActor
  end

  scope "/api", SlackApiWeb do
    pipe_through :api

    post "/conversations.create", ConversationsApiController, :create
    post "/conversations.rename", ConversationsApiController, :rename
    post "/conversations.mark", ConversationsApiController, :mark
    post "/conversations.close", ConversationsApiController, :close
    post "/conversations.join", ConversationsApiController, :join
    post "/conversations.leave", ConversationsApiController, :leave
    post "/conversations.kick", ConversationsApiController, :kick
    post "/conversations.history", ConversationsApiController, :history
    post "/conversations.setPurpose", ConversationsApiController, :setPurpose
    post "/conversations.setTopic", ConversationsApiController, :setTopic
    get "/conversations.replies", ConversationsApiController, :replies
    get "/conversations.info", ConversationsApiController, :info
    get "/conversations.list", ConversationsApiController, :list
    get "/conversations.members", ConversationsApiController, :members

    post "/chat.postMessage", ChatApiController, :post_message
    post "/chat.update", ChatApiController, :update
    post "/chat.delete", ChatApiController, :delete
    get "/chat.getPermalink", ChatApiController, :get_permalink

    get "/users.info", UsersApiController, :info
    get "/users.list", UsersApiController, :list
    get "/users.identity", UsersApiController, :identity
    get "/users.lookupByEmail", UsersApiController, :lookupByEmail
    post "/users.setPresence", UsersApiController, :setPresence
    post "/users.setPhoto", UsersApiController, :setPhoto
    get "/users.getPresence", UsersApiController, :getPresence

    post "/reminders.add", RemindersApiController, :add
    post "/reminders.complete", RemindersApiController, :complete
    post "/reminders.delete", RemindersApiController, :delete
    get "/reminders.list", RemindersApiController, :list
    get "/reminders.info", RemindersApiController, :info

    post "/reactions.add", ReactionsApiController, :add
    post "/reactions.remove", ReactionsApiController, :remove
    get "/reactions.list", ReactionsApiController, :list
    get "/reactions.get", ReactionsApiController, :get

    get "/status", ApiController, :status_test
  end

  if Application.compile_env(:slack_api, :dev_routes) do
    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
