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

      case Teams.Search.search(slug, query, limit: limit, channel_id: channel_id) do
        {:ok, results} ->
          json(conn, %{data: results})

        {:error, reason} ->
          conn
          |> put_status(:service_unavailable)
          |> json(%{error: "search_unavailable", detail: inspect(reason)})
      end
    end
  end
end
