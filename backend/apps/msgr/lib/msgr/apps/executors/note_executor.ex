defmodule Messngr.Apps.Executors.NoteExecutor do
  @moduledoc """
  Built-in executor for /note command — save a note to your personal channel.

  Usage: /note Remember to review PR #42
  """
  @behaviour Messngr.Apps.Executor

  @impl true
  def execute(%{args: nil}, _context), do: {:error, "Usage: /note Your message here"}
  def execute(%{args: ""}, _context), do: {:error, "Usage: /note Your message here"}

  def execute(%{args: text, triggered_by: account_id}, %{tenant_prefix: prefix}) do
    profile = Teams.TeamManagement.get_profile_for_account(prefix, account_id)

    if profile do
      # Find or create self-DM channel
      case Teams.Channels.create_dm(prefix, [profile.id]) do
        {:ok, channel} ->
          # Post note as a message in self-DM
          Teams.Messages.create_message(prefix, %{
            channel_id: channel.id,
            sender_profile_id: profile.id,
            content: %{"text" => "📝 #{text}"}
          })

          {:ok, %{type: :message, content: "📝 Note saved."}}

        {:error, _} ->
          {:error, "Could not save note."}
      end
    else
      {:error, "Profile not found."}
    end
  end
end
