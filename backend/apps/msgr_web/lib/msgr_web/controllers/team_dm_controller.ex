defmodule MessngrWeb.TeamDmController do
  use MessngrWeb, :controller

  alias Teams.Channels
  alias Teams.TeamManagement

  action_fallback MessngrWeb.FallbackController

  @doc "POST /api/teams/:slug/dms — create a DM channel"
  def create(conn, params) do
    prefix = conn.assigns.tenant_prefix
    account = conn.assigns.current_account

    profile = TeamManagement.get_profile_for_account(prefix, account.id)

    unless profile do
      {:error, :forbidden}
    else
      raw_ids = params["profile_ids"] || []

      # Filter out any IDs that aren't valid tenant profiles
      # (client may send account-level profile IDs by mistake)
      valid_tenant_ids =
        raw_ids
        |> Enum.filter(fn id ->
          id != profile.id and
            Teams.Repo.get(Teams.TenantModels.Profile, id, prefix: prefix) != nil
        end)

      # Always include the current user's team profile
      all_ids =
        [profile.id | valid_tenant_ids]
        |> Enum.uniq()

      if length(all_ids) < 2 do
        {:error, :bad_request}
      else
        case Channels.create_dm(prefix, all_ids) do
          {:ok, channel} ->
            conn
            |> put_status(:created)
            |> json(%{
              data: %{
                id: channel.id,
                name: channel.name,
                slug: channel.slug,
                kind: channel.kind,
                visibility: channel.visibility,
                inserted_at: channel.inserted_at
              }
            })

          {:error, changeset} ->
            {:error, changeset}
        end
      end
    end
  end
end
