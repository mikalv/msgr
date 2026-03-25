defmodule Messngr.Apps.Executors.WhoExecutor do
  @moduledoc "Lists members of the current channel."
  @behaviour Messngr.Apps.Executor

  @impl true
  def execute(%{channel_id: channel_id}, %{tenant_prefix: prefix}) do
    members = Teams.Channels.list_members(prefix, channel_id)

    if members == [] do
      {:ok, %{type: :message, content: "No members found in this channel."}}
    else
      lines = Enum.map(members, fn m ->
        name = if m.profile, do: m.profile.display_name, else: m.profile_id
        role_badge = if m.role == "admin", do: " ⭐", else: ""
        "• #{name}#{role_badge}"
      end)

      content = "**Channel members** (#{length(members)}):\n#{Enum.join(lines, "\n")}"
      {:ok, %{type: :message, content: content}}
    end
  end
end
