defmodule Messngr.Connectors.SessionVaultTest do
  use ExUnit.Case, async: true

  alias Msgr.Connectors.SessionVault
  alias Messngr.Bridges.Auth.CredentialVault

  setup do
    case :ets.whereis(:bridge_auth_credential_vault) do
      :undefined -> :ok
      table -> :ets.delete_all_objects(table)
    end

    :ok
  end

  test "scrub_and_store persists slack token map" do
    session = %{
      "token" => %{"token" => "xoxs-1", "token_type" => "user"},
      "workspace_id" => "T123",
      "user_id" => "U999"
    }

    assert {:ok, scrubbed} = SessionVault.scrub_and_store(:slack, "acct-1", "T123", session)

    assert scrubbed["workspace_id"] == "T123"
    assert scrubbed["user_id"] == "U999"
    assert Map.has_key?(scrubbed, "credential_ref")
    refute Map.has_key?(scrubbed, "token")

    {:ok, record} = CredentialVault.fetch(scrubbed["credential_ref"])
    assert record["service"] == "slack"
    assert record["session_id"] == "acct-1::T123"
    assert record["tokens"]["token"]["token"] == "xoxs-1"
    assert record["tokens"]["token"]["token_type"] == "user"
  end

  test "scrub_and_store preserves non-token fields" do
    session = %{
      "access_token" => "at-123",
      "refresh_token" => "rt-456",
      "expires_at" => 1_700_000_000,
      "extra" => %{"nested" => "value"}
    }

    assert {:ok, scrubbed} = SessionVault.scrub_and_store("teams", "acct-9", "tenant-1", session)

    assert scrubbed["expires_at"] == 1_700_000_000
    assert scrubbed["extra"]["nested"] == "value"
    assert Map.has_key?(scrubbed, "credential_ref")
    refute Map.has_key?(scrubbed, "access_token")
    refute Map.has_key?(scrubbed, "refresh_token")

    {:ok, record} = CredentialVault.fetch(scrubbed["credential_ref"])
    assert record["service"] == "teams"
    assert record["session_id"] == "acct-9::tenant-1"
    assert record["tokens"]["access_token"] == "at-123"
    assert record["tokens"]["refresh_token"] == "rt-456"
  end

  test "scrub_and_store without tokens returns scrubbed map" do
    session = %{"workspace_id" => "T987"}

    assert {:ok, scrubbed} = SessionVault.scrub_and_store(:slack, "acct-5", nil, session)
    assert scrubbed == %{"workspace_id" => "T987"}
  end
end
