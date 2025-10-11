defmodule Teams.TenantsHelperTest do
  use ExUnit.Case, async: true
  alias Teams.TenantsHelper
  alias Teams.Repo
  alias Teams.TenantTeam
  alias Plug.Conn

  import Ecto.Query, only: [from: 2]
  import Mock

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    :ok = Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})
    :ok
  end

  describe "tenant_name_from_conn/1" do
    test "returns the subdomain from the connection" do
      conn = %Conn{private: %{subdomain: "example"}}
      assert TenantsHelper.tenant_name_from_conn(conn) == "example"
    end
  end

  describe "is_tenant_name_available/1" do
    test "returns true if tenant name is available" do
      with_mock Triplex, [exists?: fn _ -> false end] do
        assert TenantsHelper.is_tenant_name_available("new_tenant")
      end
    end

    test "returns false if tenant name is not available" do
      with_mock Triplex, [exists?: fn _ -> true end] do
        refute TenantsHelper.is_tenant_name_available("existing_tenant")
      end
    end
  end

  describe "drop_tenant/1" do
    test "drops the tenant if it exists" do
      with_mock Triplex, [exists?: fn _ -> true end, drop: fn _ -> :ok end] do
        tenant = %TenantTeam{name: "existing_tenant"}
        Repo.insert!(tenant)

        assert TenantsHelper.drop_tenant("existing_tenant") == :ok
        refute Repo.get_by(TenantTeam, name: "existing_tenant")
      end
    end

    test "does nothing if tenant does not exist" do
      with_mock Triplex, [exists?: fn _ -> false end] do
        assert TenantsHelper.drop_tenant("nonexistent_tenant") == nil
      end
    end
  end

  describe "create_tenant/3" do
    test "creates a new tenant and seeds tenant space" do
      with_mock Triplex, [
        create_schema: fn _, _, _ -> :ok end,
        migrate: fn _, _ -> :ok end
      ] do
        with_mock TenantTeam, [
          create_tenant: fn _, _, _ -> {:ok, %TenantTeam{name: "new_tenant"}} end,
          get_team!: fn _ -> %TenantTeam{name: "new_tenant"} end
        ] do
          assert {:ok, %TenantTeam{name: "new_tenant"}} = TenantsHelper.create_tenant("new_tenant", "creator_uid", "description")
        end
      end
    end
  end

  describe "list_prefixes/0" do
    test "returns all tenant prefixes" do
      with_mock Triplex, [all: fn -> ["tenant1", "tenant2"] end] do
        assert TenantsHelper.list_prefixes() == ["tenant1", "tenant2"]
      end
    end
  end

  describe "seed_tenant_space/1" do
    test "seeds the tenant space with default data" do
      tenant_team_name = "new_tenant"
      with_mock Teams.TenantModels.Message, [create_system_message: fn _, _, _ -> {:ok, %Message{}} end] do
        assert TenantsHelper.seed_tenant_space(tenant_team_name) == :ok
      end
    end
  end
end
