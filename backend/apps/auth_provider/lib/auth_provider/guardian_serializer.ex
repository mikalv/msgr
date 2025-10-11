defmodule AuthProvider.GuardianSerializer do
  @behaviour Guardian.Serializer
  alias AuthProvider.Repo
  alias AuthProvider.Account.User
  def for_token(user = %User{}), do: { :ok, "uid:#{user.id}" }
  def for_token(_), do: { :error, "Unknown resource type" }
  def from_token("uid:" <> id), do: { :ok, Repo.get(User, id) }
  def from_token(_), do: { :error, "Unknown resource type" }
end
