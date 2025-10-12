defmodule MessngrWeb.AccountController do
  use MessngrWeb, :controller

  alias Messngr

  action_fallback MessngrWeb.FallbackController

  def index(conn, _params) do
    accounts = Messngr.list_accounts()
    render(conn, :index, accounts: accounts)
  end

  def create(conn, params) do
    case Messngr.create_account(params) do
      {:ok, account} ->
        conn
        |> put_status(:created)
        |> render(:show, account: account)

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update(conn, %{"id" => id} = params) do
    account = Messngr.get_account!(id)

    attrs =
      params
      |> Map.get("account")
      |> Kernel.||(params)
      |> normalize_account_attrs()

    with {:ok, _updated} <- Messngr.update_account(account, attrs) do
      account = Messngr.get_account!(id)
      render(conn, :show, account: account)
    end
  end

  defp normalize_account_attrs(params) when is_map(params) do
    params
    |> Map.take([
      "display_name",
      "handle",
      "email",
      "phone_number",
      "locale",
      "time_zone",
      "read_receipts_enabled",
      :display_name,
      :handle,
      :email,
      :phone_number,
      :locale,
      :time_zone,
      :read_receipts_enabled
    ])
    |> Enum.into(%{})
    |> normalize_read_receipts_enabled()
  end

  defp normalize_account_attrs(_), do: %{}

  defp normalize_read_receipts_enabled(attrs) do
    attrs
    |> maybe_coerce_boolean("read_receipts_enabled")
    |> maybe_coerce_boolean(:read_receipts_enabled)
  end

  defp maybe_coerce_boolean(attrs, key) do
    case Map.fetch(attrs, key) do
      {:ok, value} ->
        case coerce_boolean(value) do
          nil -> Map.delete(attrs, key)
          coerced -> Map.put(attrs, key, coerced)
        end

      :error ->
        attrs
    end
  end

  defp coerce_boolean(value) when value in [true, false], do: value
  defp coerce_boolean(value) when value in ["true", "1", 1], do: true
  defp coerce_boolean(value) when value in ["false", "0", 0], do: false
  defp coerce_boolean(_), do: nil
end
