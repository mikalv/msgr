defmodule Messngr.Apps.BuiltinCommandsTest do
  use Messngr.DataCase

  alias Messngr.Apps
  alias Messngr.Apps.BuiltinCommands

  defp create_team do
    {:ok, account} =
      Messngr.Accounts.create_account(%{
        "display_name" => "Builtin Tester",
        "email" => "builtin-#{Ecto.UUID.generate()}@example.com"
      })

    team_id = Ecto.UUID.generate()

    {:ok, team} =
      Messngr.Repo.insert(%Messngr.Teams.Team{
        id: team_id,
        name: "Builtin Test Team",
        slug: "builtin-#{Ecto.UUID.generate() |> binary_part(0, 8)}",
        schema_name: "tenant_#{team_id}"
      })

    {account, team}
  end

  describe "seed!/0" do
    test "creates built-in app and 3 commands" do
      assert :ok = BuiltinCommands.seed!()

      app = Apps.get_app_by_slug("msgr-builtin")
      assert app != nil
      assert app.name == "Msgr Built-in"
      assert app.executor_type == "builtin"

      commands =
        app
        |> Ecto.assoc(:slash_commands)
        |> Messngr.Repo.all()

      command_names = Enum.map(commands, & &1.name) |> Enum.sort()
      assert command_names == ["poll", "remind", "topic"]
    end

    test "is idempotent — calling twice does not duplicate" do
      assert :ok = BuiltinCommands.seed!()
      assert :ok = BuiltinCommands.seed!()

      app = Apps.get_app_by_slug("msgr-builtin")

      commands =
        app
        |> Ecto.assoc(:slash_commands)
        |> Messngr.Repo.all()

      assert length(commands) == 3
    end

    test "commands are findable via Apps.lookup_command" do
      :ok = BuiltinCommands.seed!()
      {_account, team} = create_team()

      for cmd_name <- ["poll", "remind", "topic"] do
        result = Apps.lookup_command(team.id, cmd_name)
        assert {app, cmd} = result
        assert app.slug == "msgr-builtin"
        assert cmd.name == cmd_name
      end
    end
  end
end
