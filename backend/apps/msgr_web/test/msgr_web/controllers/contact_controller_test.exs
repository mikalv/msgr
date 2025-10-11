defmodule MessngrWeb.ContactControllerTest do
  use MessngrWeb.ConnCase, async: true

  alias Messngr.Accounts
  alias Messngr.Accounts.Contact
  alias Messngr.Repo

  setup %{conn: conn} do
    {:ok, account} = Accounts.create_account(%{"display_name" => "Kari"})
    profile = hd(account.profiles)

    {conn, _session} = attach_noise_session(conn, account, profile)

    {:ok, conn: conn, account: account, profile: profile}
  end

  describe "POST /api/contacts/import" do
    test "persists normalized contacts and returns payload", %{conn: conn, account: account, profile: profile} do
      payload = %{
        "contacts" => [
          %{
            "name" => "  Eva   N.",
            "email" => "EVA.N@example.com ",
            "phone_number" => "+47 900 00 000",
            "labels" => ["venn", "  Kollega"],
            "metadata" => %{"source" => "device"}
          }
        ]
      }

      response_conn = post(conn, ~p"/api/contacts/import", payload)

      assert %{"data" => [contact]} = json_response(response_conn, 200)
      assert contact["name"] == "Eva   N."
      assert contact["email"] == "eva.n@example.com"
      assert contact["phone_number"] == "4790000000"
      assert contact["labels"] == ["venn", "Kollega"]
      assert contact["metadata"] == %{"source" => "device"}
      assert contact["account_id"] == account.id
      assert contact["profile_id"] == profile.id

      stored = Repo.get_by(Contact, account_id: account.id, email: "eva.n@example.com")
      assert stored
      assert stored.labels == ["venn", "Kollega"]
    end

    test "rejects payloads without contacts list", %{conn: conn} do
      response_conn = post(conn, ~p"/api/contacts/import", %{})
      assert json_response(response_conn, 400) == %{"error" => "bad_request"}
    end
  end

  describe "POST /api/contacts/lookup" do
    test "returns known matches for imported channels", %{conn: conn} do
      {:ok, identity} =
        Accounts.ensure_identity(%{kind: :email, value: "known@example.com", display_name: "Known"})

      known_account = identity.account
      known_profile = hd(known_account.profiles)

      payload = %{
        "targets" => [
          %{"email" => "known@example.com"},
          %{"phone_number" => "+47 123 45 678"}
        ]
      }

      response_conn = post(conn, ~p"/api/contacts/lookup", payload)

      assert %{"data" => [match_entry, empty_entry]} = json_response(response_conn, 200)

      assert match_entry["query"] == %{"email" => "known@example.com", "phone_number" => nil}
      assert match_entry["match"]["account_id"] == known_account.id
      assert match_entry["match"]["account_name"] == known_account.display_name
      assert match_entry["match"]["identity_kind"] == "email"
      assert match_entry["match"]["identity_value"] == "known@example.com"
      assert match_entry["match"]["profile"] == %{
               "id" => known_profile.id,
               "mode" => known_profile.mode,
               "name" => known_profile.name
             }

      assert empty_entry["query"] == %{"email" => nil, "phone_number" => "4712345678"}
      assert is_nil(empty_entry["match"])
    end

    test "rejects invalid payloads", %{conn: conn} do
      response_conn = post(conn, ~p"/api/contacts/lookup", %{})
      assert json_response(response_conn, 400) == %{"error" => "bad_request"}
    end
  end
end
