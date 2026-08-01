defmodule MessngrWeb.FallbackController do
  use MessngrWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(MessngrWeb.ErrorJSON)
    |> render("422.json", changeset: changeset)
  end

  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> json(%{error: "not_found"})
  end

  def call(conn, {:error, :forbidden}) do
    conn
    |> put_status(:forbidden)
    |> json(%{error: "forbidden"})
  end

  def call(conn, {:error, :scan_pending}) do
    conn
    |> put_status(:locked)
    |> json(%{error: "scan_pending"})
  end

  def call(conn, {:error, :infected}) do
    conn
    |> put_status(:forbidden)
    |> json(%{error: "infected"})
  end

  def call(conn, {:error, :scan_queue_full}) do
    conn
    |> put_status(:service_unavailable)
    |> json(%{error: "scan_queue_full"})
  end

  def call(conn, {:error, :too_many_attempts}) do
    conn
    |> put_status(:too_many_requests)
    |> json(%{error: "too_many_attempts"})
  end

  def call(conn, {:error, :bad_request}) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "bad_request"})
  end

  def call(conn, {:error, {:noise_handshake, reason}}) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "noise_handshake", reason: reason_to_string(reason)})
  end

  def call(conn, {:error, {:email_delivery_failed, _reason}}) do
    conn
    |> put_status(:service_unavailable)
    |> json(%{error: "email_delivery_failed"})
  end

  def call(conn, {:error, {:bulksms_error, _status, _body}}) do
    conn
    |> put_status(:service_unavailable)
    |> json(%{error: "sms_delivery_failed"})
  end

  def call(conn, {:error, {:http_error, _reason}}) do
    conn
    |> put_status(:service_unavailable)
    |> json(%{error: "delivery_failed"})
  end

  def call(conn, {:error, reason}) when is_atom(reason) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: Atom.to_string(reason)})
  end

  defp reason_to_string({:missing, key}) when is_atom(key), do: "missing_#{key}"
  defp reason_to_string(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp reason_to_string(reason), do: inspect(reason)
end
