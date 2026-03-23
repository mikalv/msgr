defmodule MessngrWeb.TeamSearchController do
  use MessngrWeb, :controller

  action_fallback MessngrWeb.FallbackController

  @doc "GET /api/teams/:slug/search?q=query&channel_id=optional"
  def index(conn, params) do
    query = Map.get(params, "q", "")

    if String.trim(query) == "" do
      json(conn, %{data: []})
    else
      slug = conn.path_params["slug"]
      channel_id = Map.get(params, "channel_id")
      limit = String.to_integer(Map.get(params, "limit", "20"))

      # Try Prism first, fall back to PostgreSQL ILIKE until Prism text-field bug is fixed
      prefix = conn.assigns.tenant_prefix

      case Teams.Search.search(slug, query, limit: limit, channel_id: channel_id) do
        {:ok, results} when results != [] ->
          json(conn, %{data: results})

        _ ->
          # PostgreSQL fallback
          case Teams.Search.search_pg(prefix, query, limit: limit, channel_id: channel_id) do
            {:ok, results} -> json(conn, %{data: results})
            {:error, _} -> json(conn, %{data: []})
          end
      end
    end
  end
end
