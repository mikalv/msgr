defmodule Messngr.Bridges.AuthTest do
  use Messngr.DataCase, async: true

  alias Messngr.Accounts
  alias Messngr.Bridges.Auth
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
end
