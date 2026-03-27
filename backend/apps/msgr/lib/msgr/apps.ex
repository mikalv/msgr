defmodule Messngr.Apps do
  @moduledoc """
  Context module for the app platform.

  Manages apps, installations, slash commands, and bot tokens.
  """

  import Ecto.Query

  alias Messngr.Repo
  alias Messngr.Apps.{App, AppInstallation, SlashCommand, BotToken}

  # ── Apps ──────────────────────────────────────────────────────

  @doc "List all apps, optionally filtered by visibility."
  def list_apps(opts \\ []) do
    query =
      from(a in App, order_by: [asc: a.name])

    query =
      case Keyword.get(opts, :visibility) do
        nil -> query
        vis -> where(query, [a], a.visibility == ^vis)
      end

    Repo.all(query)
  end

  @doc "Get an app by ID. Raises if not found."
  def get_app!(id), do: Repo.get!(App, id)

  @doc "Get an app by slug. Returns nil if not found."
  def get_app_by_slug(slug) when is_binary(slug) do
    Repo.get_by(App, slug: slug)
  end

  @doc "Create a new app."
  def create_app(attrs) do
    %App{}
    |> App.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Update an existing app."
  def update_app(%App{} = app, attrs) do
    app
    |> App.changeset(attrs)
    |> Repo.update()
  end

  # ── Installations ─────────────────────────────────────────────

  @doc "Install an app for a team."
  def install_app(app_id, team_id, config \\ %{}) do
    %AppInstallation{}
    |> AppInstallation.changeset(%{
      app_id: app_id,
      team_id: team_id,
      config: config
    })
    |> Repo.insert()
  end

  @doc "Uninstall an app (deletes the installation record)."
  def uninstall_app(installation_id) do
    case Repo.get(AppInstallation, installation_id) do
      nil -> {:error, :not_found}
      installation -> Repo.delete(installation)
    end
  end

  @doc "List all app installations for a team."
  def list_installations_for_team(team_id) do
    from(ai in AppInstallation,
      where: ai.team_id == ^team_id and ai.status == "active",
      preload: [:app]
    )
    |> Repo.all()
  end

  @doc "Get an installation by app slug and team ID."
  def get_installation_by_app_slug(app_slug, team_id) do
    from(ai in AppInstallation,
      join: a in App,
      on: a.id == ai.app_id,
      where: a.slug == ^app_slug and ai.team_id == ^team_id,
      preload: [:app]
    )
    |> Repo.one()
  end

  # ── Slash commands ────────────────────────────────────────────

  @doc "Create a slash command for an app."
  def create_command(app_id, attrs) do
    %SlashCommand{}
    |> SlashCommand.changeset(Map.put(attrs, :app_id, app_id))
    |> Repo.insert()
  end

  @doc """
  Lookup a command by name across all apps installed in a team.
  Returns `{app, command}` or `nil`.
  """
  def lookup_command(team_id, command_name) do
    query =
      from sc in SlashCommand,
        join: a in App,
        on: a.id == sc.app_id,
        left_join: ai in AppInstallation,
        on: ai.app_id == a.id and ai.team_id == ^team_id,
        where: sc.name == ^command_name,
        where: a.executor_type == "builtin" or (not is_nil(ai.id) and ai.status == "active"),
        select: {a, sc},
        limit: 1

    Repo.one(query)
  end

  @doc "List all commands available to a team (built-in + installed apps)."
  def list_commands_for_team(team_id) do
    from(sc in SlashCommand,
      join: a in App,
      on: a.id == sc.app_id,
      left_join: ai in AppInstallation,
      on: ai.app_id == a.id and ai.team_id == ^team_id,
      where: a.executor_type == "builtin" or (not is_nil(ai.id) and ai.status == "active"),
      select: %{
        name: sc.name,
        description: sc.description,
        permissions: sc.permissions,
        app_slug: a.slug,
        app_name: a.name
      }
    )
    |> Repo.all()
  end

  # ── Bot tokens ────────────────────────────────────────────────

  @doc """
  Generate a new bot token for an app installation.
  Returns `{:ok, raw_token, bot_token_record}`.
  """
  def generate_bot_token(installation_id, label, scopes \\ []) do
    {raw, hash} = BotToken.generate_token()

    attrs = %{
      app_installation_id: installation_id,
      token_hash: hash,
      label: label,
      scopes: scopes
    }

    case %BotToken{} |> BotToken.changeset(attrs) |> Repo.insert() do
      {:ok, record} -> {:ok, raw, record}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Validate a raw bot token string.
  Returns `{:ok, bot_token}` with preloaded installation + app, or `{:error, :invalid}`.
  """
  def validate_bot_token(raw_token) when is_binary(raw_token) do
    hash = BotToken.hash_token(raw_token)

    query =
      from bt in BotToken,
        where: bt.token_hash == ^hash and is_nil(bt.revoked_at),
        where: is_nil(bt.expires_at) or bt.expires_at > ^DateTime.utc_now(),
        preload: [app_installation: :app]

    case Repo.one(query) do
      nil ->
        {:error, :invalid}

      token ->
        # Update last_used_at
        token
        |> Ecto.Changeset.change(last_used_at: DateTime.utc_now() |> DateTime.truncate(:second))
        |> Repo.update()
    end
  end

  @doc "List bot tokens for an app installation (excludes revoked)."
  def list_bot_tokens(installation_id) do
    import Ecto.Query
    from(t in BotToken,
      where: t.app_installation_id == ^installation_id and is_nil(t.revoked_at),
      order_by: [desc: t.inserted_at]
    )
    |> Repo.all()
  end

  @doc "Revoke a bot token by ID."
  def revoke_bot_token(token_id) do
    case Repo.get(BotToken, token_id) do
      nil ->
        {:error, :not_found}

      token ->
        token
        |> Ecto.Changeset.change(revoked_at: DateTime.utc_now() |> DateTime.truncate(:second))
        |> Repo.update()
    end
  end
end
