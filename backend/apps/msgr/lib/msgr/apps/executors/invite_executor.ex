defmodule Messngr.Apps.Executors.InviteExecutor do
  @moduledoc "Invite a team member to the current channel by @username."
  @behaviour Messngr.Apps.Executor

  @impl true
  def execute(%{args: nil}, _context), do: {:error, "Usage: /invite @username"}
  def execute(%{args: ""}, _context), do: {:error, "Usage: /invite @username"}

  def execute(%{args: args, channel_id: channel_id}, %{tenant_prefix: prefix}) do
    username = args |> String.trim() |> String.trim_leading("@")

    if username == "" do
      {:error, "Usage: /invite @username"}
    else
      # Find profile by display_name (closest to username)
      profiles = Teams.TenantModels.Profile.list(prefix)
      profile = Enum.find(profiles, fn p ->
        String.downcase(p.display_name || "") == String.downcase(username)
      end)

      if profile do
        case Teams.Channels.add_members(prefix, channel_id, [profile.id]) do
          {:ok, count} when count > 0 ->
            {:ok, %{type: :message, content: "✅ **#{profile.display_name}** has been added to this channel."}}
          {:ok, _} ->
            {:ok, %{type: :message, content: "**#{profile.display_name}** is already in this channel."}}
          {:error, _} ->
            {:error, "Could not add #{username} to channel."}
        end
      else
        {:error, "User \"#{username}\" not found in this team."}
      end
    end
  end
end
