defmodule Messngr.Bridges.AuthTest do
  use Messngr.DataCase, async: true

  alias Messngr.Accounts
  alias Messngr.Bridges.Auth
  alias Messngr.Bridges.Auth.CredentialVault
  alias Messngr.Bridges.AuthSession

  describe "list_catalog/1" do
    test "returns configured connectors" do
      entries = Auth.list_catalog()

      assert Enum.any?(entries, &(&1.id == "telegram"))
      assert Enum.any?(entries, &(&1.status == :coming_soon))
    end

    test "filters by status" do
      entries = Auth.list_catalog(status: :available)

      assert Enum.all?(entries, &(&1.status == :available))
      assert Enum.empty?(Enum.filter(entries, &(&1.status == :coming_soon)))
    end
  end

  describe "start_session/3" do
    setup do
      {:ok, account} = Accounts.create_account(%{"display_name" => "Bridge Owner"})
      %{account: account}
    end

    test "creates session with catalog snapshot", %{account: account} do
      {:ok, %AuthSession{} = session} =
        Auth.start_session(account, "telegram", %{"client_context" => %{"platform" => "desktop"}})

      assert session.service == "telegram"
      assert session.state == "awaiting_user"
      assert session.login_method == "oauth"
      assert session.auth_surface == "embedded_browser"
      assert session.client_context["platform"] == "desktop"
      assert session.metadata["scopes"] == ["basic", "messages.read", "messages.write"]
      assert session.catalog_snapshot["id"] == "telegram"
      assert session.expires_at
    end

    test "includes consent plan metadata for teams", %{account: account} do
      {:ok, %AuthSession{} = session} = Auth.start_session(account, "teams", %{})

      plan = session.metadata["consent_plan"]
      assert is_map(plan)
      assert plan["kind"] == "embedded_browser"
      assert is_list(plan["steps"])
      assert Enum.any?(plan["steps"], fn step -> step["action"] == "resource_specific_consent" end)
    end

    test "returns error for unknown connector", %{account: account} do
      assert {:error, :unknown_connector} = Auth.start_session(account, "unknown", %{})
    end

    test "fetch_session validates ownership", %{account: account} do
      {:ok, session} = Auth.start_session(account, "matrix", %{})

      assert {:ok, %AuthSession{id: ^session.id}} = Auth.fetch_session(account, session.id)

      {:ok, other_account} = Accounts.create_account(%{"display_name" => "Other"})
      assert {:error, :forbidden} = Auth.fetch_session(other_account, session.id)
    end
  end

  describe "initiate_oauth_redirect/1 and complete_oauth_callback/2" do
    setup do
      {:ok, account} = Accounts.create_account(%{"display_name" => "OAuth Owner"})
      {:ok, session} = Auth.start_session(account, "telegram", %{})

      %{session: session}
    end

    test "persists pkce metadata and returns redirect", %{session: session} do
      assert {:ok, updated, redirect_url} = Auth.initiate_oauth_redirect(session)
      assert redirect_url =~ Auth.session_callback_path(session)

      oauth_meta = updated.metadata["oauth"]
      assert oauth_meta["state"]
      assert oauth_meta["code_verifier"]
      assert oauth_meta["code_challenge"]
      assert oauth_meta["redirect_url"] == redirect_url
    end

    test "completes callback and stores credential ref", %{session: session} do
      {:ok, session, redirect_url} = Auth.initiate_oauth_redirect(session)

      %URI{query: query} = URI.parse(redirect_url)
      params = URI.decode_query(query)

      assert {:ok, updated, %{credential_ref: ref}} = Auth.complete_oauth_callback(session, params)
      assert updated.state == "completing"
      assert updated.metadata["oauth"]["credential_ref"] == ref

      assert {:ok, record} = CredentialVault.fetch(ref)
      assert record["tokens"]["access_token"]

      public_meta = Auth.public_metadata(updated)
      refute Map.get(public_meta["oauth"], "state")
      refute Map.get(public_meta["oauth"], "code_verifier")
      assert public_meta["oauth"]["status"] == "token_stored"
    end
  end

  describe "submit_credentials/4" do
    setup do
      {:ok, account} = Accounts.create_account(%{"display_name" => "Credential Owner"})
      {:ok, session} = Auth.start_session(account, "matrix", %{})

      %{account: account, session: session}
    end

    test "queues credentials and stores summary", %{account: account, session: session} do
      credentials = %{username: "matrix-user", password: "hunter2"}

      assert {:ok, updated, summary} =
               Auth.submit_credentials(account, "matrix", session.id, credentials)

      assert updated.state == "completing"
      assert summary["fields"] == ["password", "username"]

      public_meta = Auth.public_metadata(updated)
      assert public_meta["credential_submission"]["fields"] == ["password", "username"]

      assert {:ok, stored} = Auth.checkout_credentials(session.id)
      assert stored["password"] == "hunter2"
      assert {:error, :not_found} = Auth.checkout_credentials(session.id)
    end

    test "rejects credentials for mismatched connector", %{account: account, session: session} do
      assert {:error, :connector_mismatch} =
               Auth.submit_credentials(account, "telegram", session.id, %{token: "abc"})
    end
  end
end
