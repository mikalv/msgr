defmodule Messngr.AppsTest do
  use Messngr.DataCase

  alias Messngr.Apps

  defp create_app(attrs \\ %{}) do
    defaults = %{
      slug: "test-app-#{Ecto.UUID.generate() |> binary_part(0, 8)}",
      name: "Test App",
      executor_type: "builtin",
      manifest: %{"version" => "1.0"}
    }

    Apps.create_app(Map.merge(defaults, attrs))
  end

  defp create_team do
    {:ok, account} =
      Messngr.Accounts.create_account(%{
        "display_name" => "App Tester",
        "email" => "app-#{Ecto.UUID.generate()}@example.com"
      })

    team_id = Ecto.UUID.generate()

    {:ok, team} =
      Messngr.Repo.insert(%Messngr.Teams.Team{
        id: team_id,
        name: "App Test Team",
        slug: "app-team-#{Ecto.UUID.generate() |> binary_part(0, 8)}",
        schema_name: "tenant_#{team_id}"
      })

    {account, team}
  end

  describe "create_app/1" do
    test "creates an app with required fields" do
      {:ok, app} = create_app()

      assert app.name == "Test App"
      assert app.executor_type == "builtin"
      assert app.manifest == %{"version" => "1.0"}
      assert app.status == "active"
    end

    test "validates slug format" do
      assert {:error, changeset} =
               Apps.create_app(%{slug: "INVALID SLUG", name: "Bad", executor_type: "builtin"})

      assert %{slug: [_]} = errors_on(changeset)
    end

    test "validates executor_type inclusion" do
      assert {:error, changeset} =
               Apps.create_app(%{slug: "valid-slug", name: "Bad", executor_type: "invalid"})

      assert %{executor_type: [_]} = errors_on(changeset)
    end

    test "enforces unique slug" do
      {:ok, app} = create_app(%{slug: "unique-slug"})
      assert {:error, changeset} = create_app(%{slug: "unique-slug"})
      assert %{slug: [_]} = errors_on(changeset)
    end
  end

  describe "install_app/3" do
    test "installs an app for a team" do
      {:ok, app} = create_app()
      {_account, team} = create_team()

      {:ok, installation} = Apps.install_app(app.id, team.id, %{"key" => "value"})

      assert installation.app_id == app.id
      assert installation.team_id == team.id
      assert installation.config == %{"key" => "value"}
      assert installation.status == "active"
    end

    test "prevents duplicate installations" do
      {:ok, app} = create_app()
      {_account, team} = create_team()

      {:ok, _} = Apps.install_app(app.id, team.id)
      assert {:error, changeset} = Apps.install_app(app.id, team.id)
      assert %{app_id: [_]} = errors_on(changeset)
    end
  end

  describe "lookup_command/2" do
    test "finds a builtin command without installation" do
      {:ok, app} = create_app(%{executor_type: "builtin"})
      {_account, team} = create_team()

      {:ok, _cmd} =
        Apps.create_command(app.id, %{name: "ping", description: "Ping pong"})

      result = Apps.lookup_command(team.id, "ping")
      assert {found_app, found_cmd} = result
      assert found_app.id == app.id
      assert found_cmd.name == "ping"
    end

    test "finds command for installed app" do
      {:ok, app} = create_app(%{executor_type: "webhook"})
      {_account, team} = create_team()

      {:ok, _} = Apps.install_app(app.id, team.id)

      {:ok, _cmd} =
        Apps.create_command(app.id, %{name: "deploy", description: "Deploy stuff"})

      result = Apps.lookup_command(team.id, "deploy")
      assert {found_app, found_cmd} = result
      assert found_app.id == app.id
      assert found_cmd.name == "deploy"
    end

    test "returns nil for unknown command" do
      {_account, team} = create_team()
      assert Apps.lookup_command(team.id, "nonexistent") == nil
    end

    test "returns nil for command from uninstalled non-builtin app" do
      {:ok, app} = create_app(%{executor_type: "webhook"})
      {_account, team} = create_team()

      {:ok, _cmd} =
        Apps.create_command(app.id, %{name: "private-cmd", description: "Not installed"})

      assert Apps.lookup_command(team.id, "private-cmd") == nil
    end
  end

  describe "generate_bot_token/3" do
    test "generates a token and returns raw + record" do
      {:ok, app} = create_app()
      {_account, team} = create_team()
      {:ok, installation} = Apps.install_app(app.id, team.id)

      {:ok, raw_token, record} =
        Apps.generate_bot_token(installation.id, "CI Bot", ["messages:read"])

      assert String.starts_with?(raw_token, "mbt_")
      assert record.label == "CI Bot"
      assert record.scopes == ["messages:read"]
      assert record.app_installation_id == installation.id
    end
  end

  describe "validate_bot_token/1" do
    test "validates a correct token" do
      {:ok, app} = create_app()
      {_account, team} = create_team()
      {:ok, installation} = Apps.install_app(app.id, team.id)

      {:ok, raw_token, _record} = Apps.generate_bot_token(installation.id, "Valid Bot")

      {:ok, validated} = Apps.validate_bot_token(raw_token)
      assert validated.app_installation_id == installation.id
    end

    test "rejects invalid token" do
      assert {:error, :invalid} = Apps.validate_bot_token("mbt_bogus_token_here")
    end

    test "rejects revoked token" do
      {:ok, app} = create_app()
      {_account, team} = create_team()
      {:ok, installation} = Apps.install_app(app.id, team.id)

      {:ok, raw_token, record} = Apps.generate_bot_token(installation.id, "Revoke Me")
      {:ok, _} = Apps.revoke_bot_token(record.id)

      assert {:error, :invalid} = Apps.validate_bot_token(raw_token)
    end
  end
end
