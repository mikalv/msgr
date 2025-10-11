defmodule AuthProvider.IdpTest do
  use AuthProvider.DataCase, async: true

  alias AuthProvider.Account.User
  alias AuthProvider.Idp
  alias AuthProvider.Idp.IdentityProvider
  alias AuthProvider.Idp.Tenant

  describe "tenants" do
    test "create_tenant/1 provisions a native provider by default" do
      assert {:ok, %Tenant{} = tenant} = Idp.create_tenant(%{name: "Acme Inc"})
      assert tenant.slug == "acme-inc"
      assert tenant.default_identity_provider == :native

      providers = Idp.list_identity_providers(tenant)
      assert [%IdentityProvider{} = provider] = providers
      assert provider.is_default
      assert provider.strategy == :native
    end

    test "create_tenant/1 supports external default provider configuration" do
      config = %{
        "issuer" => "https://id.acme.test",
        "client_id" => "client",
        "client_secret" => "secret",
        "authorization_endpoint" => "https://id.acme.test/authorize",
        "token_endpoint" => "https://id.acme.test/token",
        "userinfo_endpoint" => "https://id.acme.test/userinfo",
        "jwks_uri" => "https://id.acme.test/jwks"
      }

      attrs = %{
        "name" => "Beta Corp",
        "default_identity_provider" => "external_oidc",
        "default_identity_provider_config" => config,
        "default_identity_provider_slug" => "beta-oidc"
      }

      assert {:ok, %Tenant{} = tenant} = Idp.create_tenant(attrs)
      assert tenant.default_identity_provider == :external_oidc

      assert {:ok, %IdentityProvider{} = provider} = Idp.fetch_default_identity_provider(tenant)
      assert provider.slug == "beta-oidc"
      assert provider.strategy == :external_oidc
      assert provider.issuer == config["issuer"]
    end

    test "update_tenant/2 validates slug normalisation" do
      {:ok, tenant} = Idp.create_tenant(%{name: "North", slug: "Custom Slug"})

      {:ok, tenant} = Idp.update_tenant(tenant, %{slug: "Rebranded"})
      assert tenant.slug == "rebranded"
    end
  end

  describe "identity providers" do
    setup do
      {:ok, tenant} = Idp.create_tenant(%{name: "Tenant"})
      %{tenant: tenant}
    end

    test "create_identity_provider/2 enforces default uniqueness", %{tenant: tenant} do
      {:ok, %IdentityProvider{} = other} =
        Idp.create_identity_provider(tenant, %{
          name: "Upstream",
          strategy: :external_oidc,
          issuer: "https://id.upstream.test",
          client_id: "foo",
          client_secret: "bar",
          authorization_endpoint: "https://id.upstream.test/auth",
          token_endpoint: "https://id.upstream.test/token",
          is_default: true
        })

      assert {:ok, default} = Idp.fetch_default_identity_provider(tenant)
      assert default.id == other.id
      assert default.is_default
      assert length(Idp.list_identity_providers(tenant)) == 2
    end

    test "build_service_provider_client/1 supports external oidc", %{tenant: tenant} do
      {:ok, provider} =
        Idp.create_identity_provider(tenant, %{
          name: "OIDC",
          strategy: :external_oidc,
          issuer: "https://issuer.example.com",
          client_id: "client",
          client_secret: "secret",
          authorization_endpoint: "https://issuer.example.com/auth",
          token_endpoint: "https://issuer.example.com/token",
          userinfo_endpoint: "https://issuer.example.com/userinfo",
          jwks_uri: "https://issuer.example.com/jwks"
        })

      assert {:ok, client} = Idp.build_service_provider_client(provider)
      assert client.client_id == "client"
    end
  end

  describe "tokens and sessions" do
    setup do
      {:ok, tenant} = Idp.create_tenant(%{name: "Token Corp"})
      {:ok, user} = %User{} |> User.changeset(%{email: "user@example.com"}) |> Repo.insert()
      {:ok, provider} = Idp.fetch_default_identity_provider(tenant)

      conn =
        Plug.Test.conn(:get, "/")
        |> Plug.Test.init_test_session(%{})
      %{tenant: tenant, user: user, provider: provider, conn: conn}
    end

    test "issue_tokens/3 embeds tenant slug in claims", %{tenant: tenant, user: user} do
      assert {:ok, %{claims: claims}} = Idp.issue_tokens(tenant, user)
      assert claims["tenant"] == tenant.slug
    end

    test "sign_in/4 stores ids in session", %{tenant: tenant, user: user, provider: provider, conn: conn} do
      conn = Idp.sign_in(conn, tenant, user, provider)

      assert Plug.Conn.get_session(conn, "idp_tenant_id") == tenant.id
      assert Plug.Conn.get_session(conn, "idp_user_id") == user.id
      assert Plug.Conn.get_session(conn, "idp_provider_id") == provider.id

      {conn, {:ok, %{tenant: current_tenant, user: current_user, provider: current_provider}}} =
        Idp.fetch_current_session(conn)

      assert current_tenant.id == tenant.id
      assert current_user.id == user.id
      assert current_provider.id == provider.id

      conn = Idp.sign_out(conn)
      assert Plug.Conn.get_session(conn, "idp_tenant_id") == nil
    end
  end
end

