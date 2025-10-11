defmodule TeamsWeb.Subdomain.ProfileControllerTest do
  use TeamsWeb.ConnCase, async: true
  alias Teams.TenantModels.{Profile, Role}
  import Plug.Conn

  setup %{conn: conn} do
    tenant = "test_tenant"
    conn = put_private(conn, :subdomain, tenant)
    {:ok, conn: conn, tenant: tenant}
  end

  describe "list/2" do
    test "lists all profiles", %{conn: conn, tenant: tenant} do
      profiles = [%Profile{id: 1, username: "user1"}, %Profile{id: 2, username: "user2"}]
      Profile
      |> expect(:list, fn ^tenant -> profiles end)

      conn = get(conn, Routes.profile_path(conn, :list))
      assert json_response(conn, 200) == Enum.map(profiles, &TeamsWeb.Subdomain.ProfileController.filter_profile_for_json/1)
    end
  end

  describe "create/2" do
    test "creates a new profile", %{conn: conn, tenant: tenant} do
      params = %{"username" => "new_user", "first_name" => "First", "last_name" => "Last"}
      claims = %{"sub" => "user_id"}
      conn = assign(conn, :guardian_default_claims, claims)

      Profile
      |> expect(:get_by_uid, fn ^tenant, "user_id" -> nil end)
      |> expect(:quick_create_profile, fn ^tenant, "user_id", "new_user", "First", "Last" -> %Profile{id: 1, username: "new_user"} end)
      |> expect(:load_roles, fn ^tenant, %Profile{id: 1} -> %Profile{id: 1, username: "new_user"} end)

      Role
      |> expect(:get_default, fn ^tenant -> %Role{id: 1, name: "default"} end)

      Teams.TenantTeam
      |> expect(:append_members, fn ^tenant, ["user_id"] -> :ok end)

      ProfileRole
      |> expect(:upsert_profile_roles, fn ^tenant, 1, [1] -> {:ok, %Profile{id: 1, username: "new_user"}} end)

      conn = post(conn, Routes.profile_path(conn, :create), params)
      assert json_response(conn, 200) == TeamsWeb.Subdomain.ProfileController.filter_profile_for_json(%Profile{id: 1, username: "new_user"})
    end

    test "returns error if profile already exists", %{conn: conn, tenant: tenant} do
      claims = %{"sub" => "user_id"}
      conn = assign(conn, :guardian_default_claims, claims)
      existing_profile = %Profile{id: 1, username: "existing_user"}

      Profile
      |> expect(:get_by_uid, fn ^tenant, "user_id" -> existing_profile end)

      conn = post(conn, Routes.profile_path(conn, :create), %{"username" => "new_user"})
      assert json_response(conn, 400) == %{"error" => "does already exist!"}
    end
  end

  describe "update/2" do
    test "updates own profile", %{conn: conn, tenant: tenant} do
      claims = %{"sub" => "user_id"}
      conn = assign(conn, :guardian_default_claims, claims)
      authed_profile = %Profile{id: 1, username: "authed_user"}
      params = %{"profile_id" => 1, "first_name" => "Updated", "last_name" => "Name"}

      Profile
      |> expect(:get_by_uid, fn ^tenant, "user_id" -> authed_profile end)
      |> expect(:get_by_id, fn ^tenant, 1 -> authed_profile end)
      |> expect(:update, fn ^tenant, ^authed_profile, %{first_name: "Updated", last_name: "Name", settings: nil} -> {:ok, %Profile{id: 1, username: "authed_user", first_name: "Updated", last_name: "Name"}} end)

      conn = put(conn, Routes.profile_path(conn, :update), params)
      assert json_response(conn, 200) == TeamsWeb.Subdomain.ProfileController.filter_profile_for_json(%Profile{id: 1, username: "authed_user", first_name: "Updated", last_name: "Name"})
    end

    test "returns error if trying to update another profile without permission", %{conn: conn, tenant: tenant} do
      claims = %{"sub" => "user_id"}
      conn = assign(conn, :guardian_default_claims, claims)
      authed_profile = %Profile{id: 1, username: "authed_user"}
      params = %{"profile_id" => 2, "first_name" => "Updated", "last_name" => "Name"}

      Profile
      |> expect(:get_by_uid, fn ^tenant, "user_id" -> authed_profile end)
      |> expect(:can?, fn ^tenant, ^authed_profile, "can_update_other_profile" -> false end)

      conn = put(conn, Routes.profile_path(conn, :update), params)
      assert json_response(conn, 401) == %{"error" => "You're not allowed to update someone else's profile!"}
    end
  end

  describe "get/2" do
    test "gets a profile by id", %{conn: conn, tenant: tenant} do
      profile = %Profile{id: 1, username: "user1"}
      Profile
      |> expect(:get_by_id, fn ^tenant, 1 -> profile end)

      conn = get(conn, Routes.profile_path(conn, :get), %{"profile_id" => 1})
      assert json_response(conn, 200) == TeamsWeb.Subdomain.ProfileController.filter_profile_for_json(profile)
    end
  end
end
