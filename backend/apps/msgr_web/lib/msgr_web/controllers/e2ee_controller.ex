defmodule MessngrWeb.E2eeController do
  use MessngrWeb, :controller

  alias Messngr.E2ee

  action_fallback MessngrWeb.FallbackController

  def put_keys(conn, params) do
    profile = conn.assigns.current_profile

    case E2ee.put_keys(profile.id, params) do
      {:ok, result} ->
        json(conn, %{data: result})

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}

      {:error, reason} when is_atom(reason) ->
        {:error, reason}

      {:error, _reason} ->
        {:error, :bad_request}
    end
  end

  def bundles(conn, %{"profile_id" => profile_id}) do
    {:ok, bundles} = E2ee.fetch_bundles(profile_id)
    json(conn, %{data: bundles})
  end

  def count(conn, params) do
    profile = conn.assigns.current_profile
    device_id = Map.get(params, "device_id")

    if is_binary(device_id) and device_id != "" do
      {:ok, count} = E2ee.count_one_time_prekeys(profile.id, device_id)
      json(conn, %{data: %{device_id: device_id, one_time_prekey_count: count}})
    else
      {:error, :bad_request}
    end
  end
end
