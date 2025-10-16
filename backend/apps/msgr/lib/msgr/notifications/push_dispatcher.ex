defmodule Messngr.Notifications.PushDispatcher do
  @moduledoc """
  Applies delivery policy for push notifications across platforms.

  The dispatcher inspects the profile's notification and security policies,
  quiet hours, and profile mode to determine which tokens should receive the
  payload and what priority to assign.
  """

  alias Messngr.Accounts.Profile
  alias Messngr.Notifications.DevicePushToken

  @type dispatch_report :: %{attempted: non_neg_integer(), sent: list(), suppressed: list()}

  @doc """
  Returns a report describing which tokens were selected and which were
  suppressed. Actual network calls are delegated to the configured adapter.
  """
  @spec dispatch(Profile.t(), [DevicePushToken.t()], map(), keyword()) :: {:ok, dispatch_report()}
  def dispatch(%Profile{} = profile, tokens, payload, opts) do
    now = Keyword.get(opts, :now, DateTime.utc_now())
    adapter = Keyword.get(opts, :adapter, default_adapter())

    {selected, suppressed} =
      tokens
      |> Enum.map(&apply_mode_overrides(&1, profile))
      |> Enum.split_with(&deliverable?(&1, profile, now))

    send_results = Enum.map(selected, &adapter.push(&1, payload, build_context(profile, now)))

    {:ok,
     %{
       attempted: length(tokens),
       sent: send_results,
       suppressed: Enum.map(suppressed, &%{token: &1.id, reason: suppress_reason(&1, profile, now)})
     }}
  end

  defp apply_mode_overrides(token, %Profile{mode: :work}) do
    update_in(token.metadata, &Map.put(&1 || %{}, "apns-push-type", "background"))
  end

  defp apply_mode_overrides(token, %Profile{mode: :family}) do
    update_in(token.metadata, &Map.put(&1 || %{}, "importance", "high"))
  end

  defp apply_mode_overrides(token, _profile), do: token

  defp deliverable?(%DevicePushToken{status: :active} = token, profile, now) do
    profile.notification_policy["allow_push"] != false and
      not quiet_hours?(profile, now) and
      (token.mode == profile.mode or profile.mode == :family)
  end

  defp deliverable?(_token, _profile, _now), do: false

  defp quiet_hours?(%Profile{notification_policy: policy}, now) do
    quiet_hours = Map.get(policy, "quiet_hours", %{})

    case quiet_hours do
      %{"enabled" => true, "start" => start_time, "end" => end_time} ->
        within_range?(now, start_time, end_time)

      _ ->
        false
    end
  end

  defp within_range?(now, start_time, end_time) do
    with {:ok, start_time} <- Time.from_iso8601(start_time <> ":00"),
         {:ok, end_time} <- Time.from_iso8601(end_time <> ":00") do
      time = DateTime.to_time(now)

      if Time.compare(start_time, end_time) == :lt do
        Time.compare(time, start_time) != :lt and Time.compare(time, end_time) == :lt
      else
        Time.compare(time, start_time) != :lt or Time.compare(time, end_time) == :lt
      end
    else
      _ -> false
    end
  end

  defp build_context(profile, now) do
    %{
      mode: profile.mode,
      profile_id: profile.id,
      timestamp: now,
      sensitivity: profile.security_policy["sensitive_notifications"] || "hide_content"
    }
  end

  defp suppress_reason(%DevicePushToken{status: status}, _profile, _now) when status != :active do
    :inactive
  end

  defp suppress_reason(_token, %Profile{} = profile, now) do
    if quiet_hours?(profile, now), do: :quiet_hours, else: :mode_mismatch
  end

  defp default_adapter do
    Application.get_env(:msgr, __MODULE__, [])
    |> Keyword.get(:adapter, Messngr.Notifications.PushAdapters.Log)
  end
end
