defmodule Messngr.TenancyTest do
  use Messngr.DataCase

  alias Messngr.Tenancy

  @test_id Ecto.UUID.generate()

  setup do
    # Clean up any leftover test schema
    on_exit(fn ->
      try do
        Tenancy.drop_tenant(@test_id)
      rescue
        _ -> :ok
      end
    end)

    :ok
  end

  describe "create_tenant/1" do
    test "creates a PostgreSQL schema and returns the prefix" do
      schema = Tenancy.create_tenant(@test_id)
      assert schema == "tenant_#{@test_id}"

      # Verify schema exists in information_schema
      tenants = Tenancy.list_tenants()
      assert schema in tenants
    end

    test "is idempotent (CREATE SCHEMA IF NOT EXISTS)" do
      schema1 = Tenancy.create_tenant(@test_id)
      schema2 = Tenancy.create_tenant(@test_id)
      assert schema1 == schema2
    end
  end

  describe "drop_tenant/1" do
    test "drops an existing tenant schema" do
      Tenancy.create_tenant(@test_id)
      Tenancy.drop_tenant(@test_id)

      tenants = Tenancy.list_tenants()
      refute "tenant_#{@test_id}" in tenants
    end

    test "does not raise when dropping non-existent schema" do
      # Should not raise due to IF EXISTS
      Tenancy.drop_tenant(Ecto.UUID.generate())
    end
  end

  describe "list_tenants/0" do
    test "returns list of tenant schema names" do
      Tenancy.create_tenant(@test_id)
      tenants = Tenancy.list_tenants()

      assert is_list(tenants)
      assert "tenant_#{@test_id}" in tenants
    end

    test "only returns schemas matching tenant_ prefix" do
      tenants = Tenancy.list_tenants()
      Enum.each(tenants, fn name -> assert String.starts_with?(name, "tenant_") end)
    end
  end

  describe "migrate_tenant/1" do
    test "runs migrations on an existing schema without error" do
      schema = Tenancy.create_tenant(@test_id)
      # Running migrate again should be safe (no pending migrations)
      assert Tenancy.migrate_tenant(schema) == []
    end
  end

  describe "prefix/1" do
    test "returns tenant_ prefixed string" do
      id = "abc-123"
      assert Tenancy.prefix(id) == "tenant_abc-123"
    end
  end
end
