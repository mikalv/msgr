defmodule Messngr.Notifications.PushDispatcherTest do
  use Messngr.DataCase

  alias Messngr.Accounts
  alias Messngr.Notifications.{DevicePushToken, PushDispatcher}

  defmodule MemoryAdapter do
    @moduledoc false

    use Agent

    def start_link(_opts) do
      Agent.start_link(fn -> [] end, name: __MODULE__)
    end

    def push(token, payload, context) do
      Agent.update(__MODULE__, fn acc -> [%{token: token, payload: payload, context: context} | acc] end)
      %{token_id: token.id, status: :queued}
    end

    def deliveries do
      Agent.get(__MODULE__, &Enum.reverse/1)
    end
  end

  setup do
    {:ok, _} = start_supervised(MemoryAdapter)
    {:ok, account} = Accounts.create_account(%{"display_name" => "Pushy"})
    profile = List.first(account.profiles)

    token = %DevicePushToken{
      id: Ecto.UUID.generate(),
      device_id: Ecto.UUID.generate(),
      profile_id: profile.id,
      account_id: account.id,
      platform: :ios,
      token: "abc",
      status: :active,
      last_registered_at: DateTime.utc_now(),
      metadata: %{},
      mode: profile.mode
    }

    {:ok, profile: profile, token: token}
  end

  test "dispatch honours quiet hours", %{profile: profile, token: token} do
    profile = %{profile | notification_policy: Map.put(profile.notification_policy, "quiet_hours", %{"enabled" => true, "start" => "21:00", "end" => "07:00"})}

    late_night = DateTime.new!(Date.utc_today(), ~T[22:30:00], "Etc/UTC")

    {:ok, report} = PushDispatcher.dispatch(profile, [token], %{"type" => "message"}, now: late_night, adapter: MemoryAdapter)

    assert report.sent == []
    assert [%{reason: :quiet_hours}] = report.suppressed
  end

  test "dispatch sends during day", %{profile: profile, token: token} do
    morning = DateTime.new!(Date.utc_today(), ~T[09:00:00], "Etc/UTC")

    {:ok, report} = PushDispatcher.dispatch(profile, [token], %{"type" => "message"}, now: morning, adapter: MemoryAdapter)

    assert length(report.sent) == 1
    assert [] == report.suppressed

    [%{context: %{mode: :private}}] = MemoryAdapter.deliveries()
  end

  test "mode mismatch suppresses token", %{profile: profile, token: token} do
    other_token = %{token | mode: :work, id: Ecto.UUID.generate()}
    morning = DateTime.new!(Date.utc_today(), ~T[09:00:00], "Etc/UTC")

    {:ok, report} = PushDispatcher.dispatch(profile, [other_token], %{"type" => "message"}, now: morning, adapter: MemoryAdapter)

    assert report.sent == []
    assert [%{reason: :mode_mismatch}] = report.suppressed
  end

  test "family mode broadcasts to all modes" do
    {:ok, account} = Accounts.create_account(%{"display_name" => "Familie"})
    profile = hd(account.profiles)
    profile = %{profile | mode: :family}

    tokens = [
      %DevicePushToken{
        id: Ecto.UUID.generate(),
        device_id: Ecto.UUID.generate(),
        profile_id: profile.id,
        account_id: account.id,
        platform: :android,
        token: "android",
        status: :active,
        last_registered_at: DateTime.utc_now(),
        metadata: %{},
        mode: :work
      }
    ]

    {:ok, report} = PushDispatcher.dispatch(profile, tokens, %{"type" => "alert"}, adapter: MemoryAdapter)

    assert length(report.sent) == 1
  end
end
