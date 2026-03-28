defmodule Messngr.Apps.BuiltinCommands do
  @moduledoc """
  Registers built-in slash commands on application startup.

  These are first-party commands that run inside the BEAM with zero latency.
  """

  require Logger

  alias Messngr.Apps
  alias Messngr.Apps.App

  @builtin_app_slug "msgr-builtin"

  @builtin_commands [
    %{name: "poll", description: "Create a poll — /poll \"Question\" \"Option 1\" \"Option 2\""},
    %{name: "remind", description: "Set a reminder — /remind 30m Check deploy"},
    %{name: "topic", description: "Set channel topic — /topic New topic here"},
    %{name: "who", description: "List members of this channel"},
    %{name: "invite", description: "Invite a member to this channel — /invite @username"},
    %{name: "note", description: "Save a note to yourself — /note Remember to review PR"}
  ]

  @doc """
  Ensures the built-in app and its commands exist in the database.
  Idempotent — safe to call on every startup.
  """
  def seed! do
    app = ensure_builtin_app!()
    ensure_commands!(app)

    Logger.info(
      "Built-in commands registered: #{Enum.map_join(@builtin_commands, ", ", & &1.name)}"
    )

    :ok
  end

  defp ensure_builtin_app! do
    case Apps.get_app_by_slug(@builtin_app_slug) do
      nil ->
        {:ok, app} =
          Apps.create_app(%{
            slug: @builtin_app_slug,
            name: "Msgr Built-in",
            description: "Innebygde kommandoer som leveres med Msgr",
            executor_type: "builtin",
            visibility: "public",
            manifest: %{
              "schema_version" => "1",
              "app" => %{"name" => "Msgr Built-in", "slug" => @builtin_app_slug}
            }
          })

        app

      %App{} = app ->
        app
    end
  end

  defp ensure_commands!(app) do
    existing =
      app
      |> Ecto.assoc(:slash_commands)
      |> Messngr.Repo.all()
      |> MapSet.new(& &1.name)

    for cmd <- @builtin_commands, cmd.name not in existing do
      {:ok, _} =
        Apps.create_command(app.id, %{
          name: cmd.name,
          description: cmd.description,
          permissions: "member"
        })
    end
  end
end
