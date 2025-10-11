defmodule SlackApiWeb.Controllers.UsersApiController do
  use SlackApiWeb, :controller

  alias Messngr
  alias Messngr.Accounts
  alias Messngr.Accounts.Profile
  alias SlackApi.{SlackAdapter, SlackId, SlackResponse}

  def info(conn, params) do
    current_account = conn.assigns.current_account

    with {:ok, user_id} <- fetch_required(params, "user"),
         {:ok, profile} <- fetch_profile(user_id, current_account.id) do
      payload = SlackAdapter.profile(profile, current_account)
      json(conn, SlackResponse.success(%{user: payload}))
    else
      {:error, :missing_user} ->
        json(conn, SlackResponse.error(:missing_user))

      {:error, :not_found} ->
        json(conn, SlackResponse.error(:user_not_found))
    end
  end

  def list(conn, _params) do
    current_account = conn.assigns.current_account

    profiles = Accounts.list_profiles(current_account.id)

    payload = Enum.map(profiles, &SlackAdapter.profile(&1, current_account))

    json(conn, SlackResponse.success(%{members: payload}))
  end

  def identity(conn, _params) do
    current_account = conn.assigns.current_account
    current_profile = conn.assigns.current_profile

    profile_payload = SlackAdapter.profile(current_profile, current_account)

    response =
      SlackResponse.success(%{
        user: profile_payload,
        team: %{id: SlackId.team(current_account), name: current_account.display_name}
      })

    json(conn, response)
  end

  def lookupByEmail(conn, params) do
    current_account = conn.assigns.current_account

    with {:ok, email} <- fetch_required(params, "email"),
         {:ok, identity} <- lookup_identity(email),
         {:ok, profile} <- find_profile_for_account(identity.account_id, current_account.id) do
      payload = SlackAdapter.profile(profile, current_account)
      json(conn, SlackResponse.success(%{user: payload}))
    else
      {:error, :missing_email} ->
        json(conn, SlackResponse.error(:missing_email))

      {:error, :identity_not_found} ->
        json(conn, SlackResponse.error(:users_not_found))

      {:error, :not_found} ->
        json(conn, SlackResponse.error(:users_not_found))
    end
  end

  def setPresence(conn, params) do
    presence = Map.get(params, "presence", "auto")
    json(conn, SlackResponse.success(%{presence: presence}))
  end

  def getPresence(conn, _params) do
    json(conn, SlackResponse.success(%{presence: "active", online: true}))
  end

  def setPhoto(conn, _params) do
    json(conn, SlackResponse.error(:not_implemented))
  end

  defp fetch_profile(user_id, account_id) do
    with {:ok, id} <- decode_user_id(user_id),
         %Profile{} = profile <- Messngr.get_profile!(id) do
      if profile.account_id == account_id do
        {:ok, profile}
      else
        {:error, :not_found}
      end
    else
      _ -> {:error, :not_found}
    end
  rescue
    _ -> {:error, :not_found}
  end

  defp lookup_identity(email) do
    case Accounts.get_identity_by_channel(:email, email) do
      nil -> {:error, :identity_not_found}
      identity -> {:ok, identity}
    end
  end

  defp find_profile_for_account(account_id, current_account_id)
       when account_id == current_account_id do
    case Accounts.list_profiles(account_id) do
      [%Profile{} = profile | _] -> {:ok, profile}
      _ -> {:error, :not_found}
    end
  end

  defp find_profile_for_account(_account_id, _current_account_id), do: {:error, :not_found}

  defp decode_user_id(user_id) do
    case SlackId.decode_profile(user_id) do
      {:ok, id} -> {:ok, id}
      :error -> {:error, :not_found}
    end
  end

  defp fetch_required(params, key) do
    case Map.get(params, key) do
      nil -> {:error, :"missing_#{key}"}
      "" -> {:error, :"missing_#{key}"}
      value -> {:ok, value}
    end
  end
end
