defmodule MessngrWeb.TeamProfileController do
  use MessngrWeb, :controller

  alias Teams.TeamManagement
  alias Teams.TenantModels.Profile

  action_fallback MessngrWeb.FallbackController

  @doc "GET /api/teams/:slug/profiles — list team members"
  def index(conn, _params) do
    prefix = conn.assigns.tenant_prefix
    profiles = Profile.list(prefix)
    json(conn, %{data: Enum.map(profiles, &profile_json/1)})
  end

  @doc "GET /api/teams/:slug/profiles/:id — show a single team profile"
  def show(conn, %{"id" => profile_id}) do
    prefix = conn.assigns.tenant_prefix

    case Profile.get_by_id(prefix, profile_id) do
      nil ->
        {:error, :not_found}

      profile ->
        json(conn, %{data: profile_json(profile)})
    end
  end

  @doc "PUT /api/teams/:slug/profiles/me — update my team profile"
  def update(conn, params) do
    prefix = conn.assigns.tenant_prefix
    account = conn.assigns.current_account

    case TeamManagement.get_profile_for_account(prefix, account.id) do
      nil ->
        {:error, :not_found}

      profile ->
        attrs = %{}
        attrs = if params["display_name"], do: Map.put(attrs, :display_name, params["display_name"]), else: attrs
        attrs = if params["avatar_url"], do: Map.put(attrs, :avatar_url, params["avatar_url"]), else: attrs
        attrs = if params["email"], do: Map.put(attrs, :email, params["email"]), else: attrs
        attrs = if params["phone"], do: Map.put(attrs, :phone, params["phone"]), else: attrs

        case Profile.update(prefix, profile, attrs) do
          {:ok, updated} ->
            json(conn, %{data: profile_json(updated)})

          {:error, changeset} ->
            {:error, changeset}
        end
    end
  end

  defp profile_json(profile) do
    %{
      id: profile.id,
      account_id: profile.account_id,
      display_name: profile.display_name,
      avatar_url: profile.avatar_url,
      email: profile.email,
      phone: profile.phone,
      role: profile.role,
      inserted_at: profile.inserted_at
    }
  end
end
