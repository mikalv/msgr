defmodule Messngr.Apps.WebhookDispatch do
  @moduledoc """
  Dispatches events to subscribed app webhooks with HMAC signing and retry logic.

  Events: message:created, message:edited, message:deleted, member:joined,
  member:left, channel:created, reaction:added, reaction:removed.
  """

  require Logger

  alias Messngr.Repo
  alias Messngr.Apps.{App, AppInstallation}

  import Ecto.Query

  @max_retries 5
  @initial_backoff_ms 1_000

  @doc """
  Dispatch an event to all apps installed in a team that have a webhook_url.
  Runs async (spawns tasks) to avoid blocking the caller.
  """
  def dispatch(team_id, event, payload) do
    installations = list_webhook_installations(team_id)

    for inst <- installations do
      Task.Supervisor.start_child(
        Messngr.TaskSupervisor,
        fn -> deliver(inst, event, payload) end
      )
    end

    :ok
  end

  @doc "List app installations for a team that have webhook URLs."
  def list_webhook_installations(team_id) do
    from(i in AppInstallation,
      join: a in App, on: a.id == i.app_id,
      where: i.team_id == ^team_id and i.status == "active" and not is_nil(a.webhook_url),
      preload: [:app]
    )
    |> Repo.all()
  end

  @doc "Deliver an event to a single app installation's webhook."
  def deliver(installation, event, payload, attempt \\ 1) do
    app = installation.app
    url = app.webhook_url
    secret = app.webhook_secret

    body = Jason.encode!(%{
      event: event,
      team_id: installation.team_id,
      app_id: app.id,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      data: payload
    })

    headers = [
      {"Content-Type", "application/json"},
      {"X-Relay-Event", event},
      {"X-Relay-Delivery", Ecto.UUID.generate()},
    ]

    # Add HMAC signature if secret is configured
    headers = if secret && secret != "" do
      sig = :crypto.mac(:hmac, :sha256, secret, body) |> Base.encode16(case: :lower)
      [{"X-Relay-Signature", "sha256=#{sig}"} | headers]
    else
      headers
    end

    case Finch.build(:post, url, headers, body)
         |> Finch.request(Messngr.Finch, receive_timeout: 10_000) do
      {:ok, %{status: status}} when status in 200..299 ->
        Logger.info("[WebhookDispatch] #{event} → #{app.slug}: #{status}")
        :ok

      {:ok, %{status: status}} ->
        Logger.warning("[WebhookDispatch] #{event} → #{app.slug}: HTTP #{status} (attempt #{attempt})")
        maybe_retry(installation, event, payload, attempt)

      {:error, reason} ->
        Logger.warning("[WebhookDispatch] #{event} → #{app.slug}: #{inspect(reason)} (attempt #{attempt})")
        maybe_retry(installation, event, payload, attempt)
    end
  end

  defp maybe_retry(_installation, _event, _payload, attempt) when attempt >= @max_retries do
    Logger.error("[WebhookDispatch] Max retries reached, giving up")
    :error
  end

  defp maybe_retry(installation, event, payload, attempt) do
    backoff = @initial_backoff_ms * :math.pow(2, attempt - 1) |> round()
    Process.sleep(backoff)
    deliver(installation, event, payload, attempt + 1)
  end
end
