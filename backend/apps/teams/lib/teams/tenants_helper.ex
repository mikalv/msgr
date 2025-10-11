defmodule Teams.TenantsHelper do
  alias Teams.TenantTeam
  alias Teams.Repo
  alias Teams.TenantModels.{Conversation, Message, Profile, Role, Room}
  require Logger

  def tenant_name_from_conn(%Plug.Conn{} = conn), do: conn.private[:subdomain]

  def is_tenant_name_available(name), do: not Triplex.exists?(name)

  def drop_tenant(name) do
    if Triplex.exists?(name) do
      tenant_record = Repo.get_by(TenantTeam, name: name)
      Repo.delete(tenant_record)
      Triplex.drop(name)
    end
  end

  def create_tenant(name, creator_uid, description \\ "") do
    Triplex.create_schema(name, Repo, fn(tenant, repo) ->
      {:ok, _} = Triplex.migrate(tenant, repo)

      Repo.transaction(fn ->
        with {:ok, account} <- TenantTeam.create_tenant(tenant, creator_uid, description),
        :ok = seed_tenant_space(tenant) do
          Logger.info "Created new tenant #{inspect account}"
          {:ok, account}
        else
          {:error, error} ->
            Logger.error "Error: #{inspect error}"
            Repo.rollback(error)
        end
      end)
    end)
    {:ok, TenantTeam.get_team!(name)}
  end

  def list_prefixes(), do: Triplex.all

  def seed_tenant_space(tenant_team_name) do
    admin_permissions = [
      "can_create_room",
      "can_update_room",
      "can_delete_room",
      "can_create_secret_conversation",
      "can_invite_user",
      "can_kick_user",
      "can_update_other_profile",
      "can_delete_other_message",
    ]
    default_permissions = ["can_create_room"]
    general_room = Room.changeset(%Room{}, %{name: "General", description: "The default chat room", members: ["all"]})
    admin_role = Role.changeset(%Role{}, %{name: "Owner", permissions: admin_permissions})
    default_role = Role.changeset(%Role{}, %{name: "User", permissions: default_permissions, is_default: true})


    changesets = [general_room, admin_role, default_role]
    results = Enum.map(changesets, fn x -> insert_to_db(tenant_team_name, x) end)

    {:ok, _msg} = Teams.TenantModels.Message.create_system_message(tenant_team_name, Map.get(List.first(results), :id), "Hello and welcome!")
    :ok
  end

  def insert_to_db(tenant_team_name, query), do: Repo.insert!(query, prefix: Triplex.to_prefix(tenant_team_name))
end
