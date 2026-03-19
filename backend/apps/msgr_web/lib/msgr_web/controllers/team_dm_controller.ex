defmodule MessngrWeb.TeamDmController do
  use MessngrWeb, :controller

  alias Messngr.Channels
  alias Messngr.Teams

  action_fallback MessngrWeb.FallbackController

  @doc "POST /api/teams/:slug/dms — create a DM channel"
  def create(conn, params) do
    prefix = conn.assigns.tenant_prefix
    account = conn.assigns.current_actor

    profile = Teams.get_profile_for_account(prefix, account.id)

    unless profile do
      {:error, :forbidden}
    else
      profile_ids = params["profile_ids"] || []

      # Always include the current user
      all_ids =
        [profile.id | profile_ids]
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
