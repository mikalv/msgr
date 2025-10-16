defmodule Messngr.Notifications do
  @moduledoc """
  Notification subsystem entry point.

  Provides helpers for registering device push tokens and dispatching payloads
  via the configured adapters. Delivery policies honour the profile's mode and
  notification preferences.
  """

  import Ecto.Query

  alias Messngr.Accounts.{Device, Profile}
  alias Messngr.Notifications.{DevicePushToken, PushDispatcher}
  alias Messngr.Repo

  @type push_payload :: map()

  @doc """
  Registers or updates a push token for the specified device.
  """
  @spec register_push_token(Device.t(), map()) :: {:ok, DevicePushToken.t()} | {:error, Ecto.Changeset.t()}
  def register_push_token(%Device{} = device, attrs) do
    Repo.transaction(fn ->
      profile = Repo.preload(device, :profile).profile

      existing =
        Repo.one(
          from token in DevicePushToken,
            where: token.device_id == ^device.id and token.platform == ^attrs[:platform],
            lock: "FOR UPDATE"
        )

      merged_attrs =
        attrs
        |> Map.put(:device_id, device.id)
        |> Map.put(:profile_id, profile.id)
        |> Map.put(:account_id, profile.account_id)
        |> Map.put(:last_registered_at, DateTime.utc_now())
        |> Map.put_new(:metadata, %{})
        |> Map.put_new(:mode, profile.mode)

      case existing do
        nil ->
          %DevicePushToken{}
          |> DevicePushToken.changeset(merged_attrs)
          |> Repo.insert()

        token ->
          token
          |> DevicePushToken.changeset(merged_attrs)
          |> Repo.update()
      end
    end)
    |> case do
      {:ok, {:ok, token}} -> {:ok, token}
      {:ok, {:error, changeset}} -> {:error, changeset}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Disables all push tokens for the provided device.
  """
  @spec disable_push_tokens(Device.t()) :: :ok
  def disable_push_tokens(%Device{} = device) do
    from(token in DevicePushToken, where: token.device_id == ^device.id)
    |> Repo.update_all(set: [status: :disabled])

    :ok
  end

  @doc """
  Dispatches a push payload for the given profile.
  """
  @spec dispatch_push(Profile.t(), push_payload(), keyword()) :: {:ok, PushDispatcher.dispatch_report()}
  def dispatch_push(%Profile{} = profile, payload, opts \\ []) when is_map(payload) do
    tokens = list_active_tokens(profile)
    PushDispatcher.dispatch(profile, tokens, payload, opts)
  end

  defp list_active_tokens(%Profile{id: profile_id}) do
    Repo.all(
      from token in DevicePushToken,
        where: token.profile_id == ^profile_id and token.status == :active
    )
  end
end
