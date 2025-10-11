defmodule MessngrWeb.FamilyEventController do
  use MessngrWeb, :controller

  alias FamilySpace

  action_fallback MessngrWeb.FallbackController

  def index(conn, %{"family_id" => family_id} = params) do
    current_profile = conn.assigns.current_profile

    with _membership <- FamilySpace.ensure_membership(family_id, current_profile.id),
         {:ok, filters} <- build_filters(params) do
      events = FamilySpace.list_events(family_id, filters)
      render(conn, :index, events: events)
    end
  rescue
    Ecto.NoResultsError -> {:error, :forbidden}
  end

  def create(conn, %{"family_id" => family_id, "event" => event_params}) do
    current_profile = conn.assigns.current_profile

    with {:ok, attrs} <- normalize_event_params(event_params, required: [:starts_at, :title]),
         {:ok, event} <- FamilySpace.create_event(family_id, current_profile.id, attrs) do
      conn
      |> put_status(:created)
      |> render(:show, event: event)
    end
  rescue
    Ecto.NoResultsError -> {:error, :forbidden}
  end

  def show(conn, %{"family_id" => family_id, "id" => event_id}) do
    current_profile = conn.assigns.current_profile

    with _membership <- FamilySpace.ensure_membership(family_id, current_profile.id),
         event <- FamilySpace.get_event!(family_id, event_id) do
      render(conn, :show, event: event)
    end
  rescue
    Ecto.NoResultsError -> {:error, :forbidden}
  end

  def update(conn, %{"family_id" => family_id, "id" => event_id, "event" => event_params}) do
    current_profile = conn.assigns.current_profile

    with {:ok, attrs} <- normalize_event_params(event_params),
         {:ok, event} <- FamilySpace.update_event(family_id, event_id, current_profile.id, attrs) do
      render(conn, :show, event: event)
    end
  rescue
    Ecto.NoResultsError -> {:error, :forbidden}
  end

  def delete(conn, %{"family_id" => family_id, "id" => event_id}) do
    current_profile = conn.assigns.current_profile

    with {:ok, _} <- FamilySpace.delete_event(family_id, event_id, current_profile.id) do
      send_resp(conn, :no_content, "")
    end
  rescue
    Ecto.NoResultsError -> {:error, :forbidden}
  end

  defp build_filters(params) do
    with {:ok, from} <- parse_optional_datetime(Map.get(params, "from")),
         {:ok, to} <- parse_optional_datetime(Map.get(params, "to")) do
      filters = [] |> maybe_put(:from, from) |> maybe_put(:to, to)
      {:ok, filters}
    else
      :error -> {:error, :bad_request}
    end
  end

  defp normalize_event_params(params, opts \\ []) do
    params = Map.new(params, fn {key, value} -> {to_string(key), value} end)

    required =
      opts
      |> Keyword.get(:required, [])
      |> Enum.map(&to_string/1)

    with :ok <- ensure_required(params, required),
         {:ok, params} <- maybe_put_datetime(params, "starts_at"),
         {:ok, params} <- maybe_put_datetime(params, "ends_at") do
      {:ok, params}
    else
      :error -> {:error, :bad_request}
    end
  end

  defp ensure_required(_params, []), do: :ok

  defp ensure_required(params, required) do
    case Enum.find(required, &is_nil(Map.get(params, &1))) do
      nil -> :ok
      _ -> :error
    end
  end

  defp maybe_put_datetime(params, key) do
    case Map.fetch(params, key) do
      :error -> {:ok, params}
      {:ok, nil} -> {:ok, params}
      {:ok, value} ->
        case parse_datetime(value) do
          {:ok, datetime} -> {:ok, Map.put(params, key, datetime)}
          :error -> :error
        end
    end
  end

  defp parse_optional_datetime(nil), do: {:ok, nil}

  defp parse_optional_datetime(value) do
    case parse_datetime(value) do
      {:ok, datetime} -> {:ok, datetime}
      :error -> :error
    end
  end

  defp parse_datetime(%DateTime{} = datetime), do: {:ok, datetime}

  defp parse_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> {:ok, datetime}
      :error -> :error
    end
  end

  defp parse_datetime(_), do: :error

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
