defmodule MessngrWeb.MessageController do
  use MessngrWeb, :controller

  alias Messngr

  action_fallback MessngrWeb.FallbackController

  def index(conn, %{"id" => conversation_id} = params) do
    current_profile = conn.assigns.current_profile

    with _participant <- Messngr.ensure_membership(conversation_id, current_profile.id) do
      page = Messngr.list_messages(conversation_id, build_list_opts(params))

      render(conn, :index, page: page)
    end
  rescue
    Ecto.NoResultsError -> {:error, :forbidden}
  end

  def create(conn, %{"id" => conversation_id, "message" => message_params}) do
    current_profile = conn.assigns.current_profile

    with _participant <- Messngr.ensure_membership(conversation_id, current_profile.id),
         {:ok, message} <- Messngr.send_message(conversation_id, current_profile.id, message_params) do
      conn
      |> put_status(:created)
      |> render(:show, message: message)
    else
      {:error, reason} -> {:error, reason}
    end
  rescue
    Ecto.NoResultsError -> {:error, :forbidden}
  end

  def create(_conn, _params), do: {:error, :bad_request}

  def deliver(conn, %{"id" => conversation_id, "message_id" => message_id} = params) do
    current_profile = conn.assigns.current_profile

    with _participant <- Messngr.ensure_membership(conversation_id, current_profile.id),
         {:ok, receipt} <-
           Messngr.acknowledge_message_delivery(
             conversation_id,
             current_profile.id,
             message_id,
             delivery_opts(conn, params)
           ) do
      conn
      |> put_status(:ok)
      |> render(:receipt, receipt: receipt)
    else
      {:error, reason} -> {:error, reason}
    end
  rescue
    Ecto.NoResultsError -> {:error, :forbidden}
  end

  defp build_list_opts(params) do
    []
    |> maybe_put(:limit, params["limit"])
    |> maybe_put(:before_id, params["before_id"])
    |> maybe_put(:after_id, params["after_id"])
    |> maybe_put(:around_id, params["around_id"])
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, :limit, value) do
    case Integer.parse(to_string(value)) do
      {int, _} when int > 0 and int <= 200 -> Keyword.put(opts, :limit, int)
      _ -> opts
    end
  end

  defp maybe_put(opts, :before_id, value), do: Keyword.put(opts, :before_id, value)
  defp maybe_put(opts, :after_id, value), do: Keyword.put(opts, :after_id, value)
  defp maybe_put(opts, :around_id, value), do: Keyword.put(opts, :around_id, value)

  defp delivery_opts(conn, params) do
    base = %{}
    base = maybe_put_device(base, conn.assigns[:current_device])
    maybe_put_device_id(base, Map.get(params, "device_id") || Map.get(params, "deviceId"))
  end

  defp maybe_put_device(opts, nil), do: opts
  defp maybe_put_device(opts, device), do: Map.put(opts, :device, device)

  defp maybe_put_device_id(opts, nil), do: opts
  defp maybe_put_device_id(opts, device_id), do: Map.put(opts, :device_id, device_id)
end
