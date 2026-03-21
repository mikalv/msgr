defmodule MessngrWeb.SettingsController do
  use MessngrWeb, :controller

  alias Messngr

  action_fallback MessngrWeb.FallbackController

  @doc """
  GET /api/settings — returns the current account's settings.
  """
  def show(conn, _params) do
    account_id = conn.assigns.current_account.id

    with {:ok, settings} <- Messngr.get_settings(account_id) do
      json(conn, settings_to_json(settings))
    end
  end

  @doc """
  PUT /api/settings — upserts the current account's settings.
  """
  def update(conn, params) do
    account_id = conn.assigns.current_account.id
    attrs = extract_settings_attrs(params)

    with {:ok, settings} <- Messngr.update_settings(account_id, attrs) do
      json(conn, settings_to_json(settings))
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  @allowed_keys ~w(
    notify_desktop notify_mobile notify_about notify_thread_replies notify_sounds
    dnd_enabled dnd_start dnd_end
    show_online_status show_read_receipts show_typing_indicators
    locale date_format time_24h
    status_text status_emoji status_expires_at
  )

  defp extract_settings_attrs(params) do
    (Map.get(params, "settings") || params)
    |> Map.take(@allowed_keys)
    |> Enum.into(%{})
  end

  defp settings_to_json(settings) do
    %{
      account_id: settings.account_id,
      notify_desktop: settings.notify_desktop,
      notify_mobile: settings.notify_mobile,
      notify_about: settings.notify_about,
      notify_thread_replies: settings.notify_thread_replies,
      notify_sounds: settings.notify_sounds,
      dnd_enabled: settings.dnd_enabled,
      dnd_start: time_to_string(settings.dnd_start),
      dnd_end: time_to_string(settings.dnd_end),
      show_online_status: settings.show_online_status,
      show_read_receipts: settings.show_read_receipts,
      show_typing_indicators: settings.show_typing_indicators,
      locale: settings.locale,
      date_format: settings.date_format,
      time_24h: settings.time_24h,
      status_text: settings.status_text,
      status_emoji: settings.status_emoji,
      status_expires_at: settings.status_expires_at,
      updated_at: settings.updated_at
    }
  end

  defp time_to_string(nil), do: nil
  defp time_to_string(%Time{} = t), do: Time.to_string(t)
end
