defmodule MessngrWeb.ProfileController do
  use MessngrWeb, :controller

  alias Messngr

  action_fallback MessngrWeb.FallbackController

  def index(conn, _params) do
    current_account = conn.assigns.current_account
    current_profile = conn.assigns.current_profile

    profiles = Messngr.list_profiles(current_account.id)

    render(conn, :index,
      profiles: profiles,
      current_profile_id: current_profile && current_profile.id
    )
  end

  def create(conn, params) do
    current_account = conn.assigns.current_account

    attrs =
      params
      |> extract_profile_attrs()
      |> Map.put("account_id", current_account.id)

    case Messngr.create_profile(attrs) do
      {:ok, profile} ->
        conn
        |> put_status(:created)
        |> render(:show, profile: profile)

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def update(conn, %{"id" => id} = params) do
    current_account = conn.assigns.current_account

    with {:ok, profile} <- Messngr.ensure_profile_for_account(current_account.id, id),
         attrs <- extract_profile_attrs(params),
         {:ok, profile} <- Messngr.update_profile(profile, attrs) do
      render(conn, :show, profile: profile)
    end
  end

  def delete(conn, %{"id" => id}) do
    current_account = conn.assigns.current_account
    current_profile = conn.assigns.current_profile

    with {:ok, profile} <- Messngr.ensure_profile_for_account(current_account.id, id),
         :ok <- ensure_not_active(profile, current_profile),
         {:ok, _} <- Messngr.delete_profile(profile) do
      send_resp(conn, :no_content, "")
    else
      {:error, :cannot_delete_last_profile} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "cannot_delete_last_profile"})

      {:error, :cannot_delete_active_profile} ->
        conn
        |> put_status(:conflict)
        |> json(%{error: "cannot_delete_active_profile"})

      {:error, other} ->
        {:error, other}
    end
  end

  def switch(conn, %{"id" => id}) do
    current_account = conn.assigns.current_account
    encoded_token = conn.assigns.noise_session_token

    with {:ok, result} <- Messngr.switch_profile(encoded_token, current_account.id, id) do
      conn =
        conn
        |> assign(:noise_session, result.session)
        |> assign(:noise_session_token, result.token)
        |> assign(:current_profile, result.profile)
        |> maybe_assign_device(result.device)
        |> put_session(:noise_session_token, result.token)

      render(conn, :switch, profile: result.profile, token: result.token, device: result.device)
    end
  end

  defp extract_profile_attrs(params) when is_map(params) do
    (Map.get(params, "profile") || params)
    |> Map.take([
      "name",
      "slug",
      "mode",
      "theme",
      "notification_policy",
      "security_policy",
      :name,
      :slug,
      :mode,
      :theme,
      :notification_policy,
      :security_policy
    ])
    |> Enum.into(%{})
  end

  defp ensure_not_active(_profile, nil), do: :ok

  defp ensure_not_active(profile, current) do
    if current && profile.id == current.id do
      {:error, :cannot_delete_active_profile}
    else
      :ok
    end
  end

  defp maybe_assign_device(conn, nil), do: conn
  defp maybe_assign_device(conn, device), do: assign(conn, :current_device, device)
end
