defmodule Messngr.Apps.Executor do
  @moduledoc """
  Behaviour for app command executors.

  Each executor mode (builtin, webhook, bot, llm) implements this behaviour
  to handle slash command execution.
  """

  @type command :: %{
          command: String.t(),
          args: String.t() | nil,
          channel_id: String.t(),
          triggered_by: String.t()
        }

  @type context :: %{
          team_id: String.t(),
          tenant_prefix: String.t(),
          app: Messngr.Apps.App.t(),
          installation: Messngr.Apps.AppInstallation.t() | nil,
          config: map()
        }

  @callback execute(command :: command(), context :: context()) ::
              {:ok, map()} | {:error, term()}
end
