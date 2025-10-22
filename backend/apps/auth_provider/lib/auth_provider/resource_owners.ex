defmodule AuthProvider.ResourceOwners do
  @behaviour Boruta.Oauth.ResourceOwners
  alias Boruta.Oauth.ResourceOwner
  alias AuthProvider.Account.User
  alias AuthProvider.Repo
  require Logger

  @impl Boruta.Oauth.ResourceOwners
  def get_by(username: _username) do
  end

  def get_by(sub: _sub) do
  end

  @impl Boruta.Oauth.ResourceOwners
  def check_password(resource_owner, password) do
    user = Repo.get_by(User, id: resource_owner.sub)

    cond do
      function_exported?(User, :valid_password?, 2) ->
        case apply(User, :valid_password?, [user, password]) do
          true -> :ok
          false -> {:error, "Invalid email or password."}
        end

      true ->
        Logger.warning("User.valid_password?/2 is not implemented; rejecting password check")
        {:error, "Invalid email or password."}
    end
  end

  @impl Boruta.Oauth.ResourceOwners
  def authorized_scopes(%ResourceOwner{}), do: []

  @impl Boruta.Oauth.ResourceOwners
  def claims(_resource_owner, _scope), do: %{}
end
