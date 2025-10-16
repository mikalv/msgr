defmodule MessngrWeb.ProfileJSON do
  alias Messngr.Accounts.{Device, Profile}

  def index(%{profiles: profiles, current_profile_id: current_id}) do
    %{data: Enum.map(profiles, &profile_payload(&1, current_id))}
  end

  def show(%{profile: profile}) do
    %{data: serialize_profile(profile)}
  end

  def switch(%{profile: profile, token: token, device: device}) do
    %{
      data: %{
        profile: serialize_profile(profile),
        noise_session: %{token: token},
        device: maybe_device(device)
      }
    }
  end

  defp profile_payload(%Profile{} = profile, current_id) do
    serialize_profile(profile)
    |> Map.put(:is_active, current_id == profile.id)
  end

  defp serialize_profile(%Profile{} = profile) do
    %{
      id: profile.id,
      name: profile.name,
      slug: profile.slug,
      mode: profile.mode,
      theme: profile.theme,
      notification_policy: profile.notification_policy,
      security_policy: profile.security_policy
    }
  end

  defp maybe_device(%Device{} = device) do
    %{
      id: device.id,
      profile_id: device.profile_id,
      account_id: device.account_id,
      enabled: device.enabled
    }
  end

  defp maybe_device(_), do: nil
end
