defmodule TeamsWeb.GraphQL.Resolvers.Profile do

  def get_current_user(_, _, resolution) do
    user = resolution.context[:current_user]
    {:ok, user}
  end
end
