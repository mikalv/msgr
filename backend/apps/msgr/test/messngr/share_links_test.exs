defmodule Messngr.ShareLinksTest do
  use Messngr.DataCase, async: true

  alias Ecto.Changeset
  alias Messngr.Accounts.Account
  alias Messngr.Bridges.BridgeAccount
  alias Messngr.Repo
  alias Messngr.ShareLinks

  describe "create_link/1" do
    test "persists defaults for image payloads" do
      account = insert_account!("Share Link User")

      attrs = %{
        account_id: account.id,
        kind: :image,
        title: "Holiday photo",
        payload: %{"download" => %{"url" => "https://cdn.example.org/photo.jpg"}}
      }

      assert {:ok, link} = ShareLinks.create_link(attrs)
      assert link.kind == :image
      refute ShareLinks.expired?(link)
      assert link.capabilities["targets"]["irc"]["mode"] == "link_only"
      assert ShareLinks.public_url(link) =~ link.token
      assert ShareLinks.msgr_url(link) =~ link.token
    end

    test "accepts custom expiry and capability overrides" do
      account = insert_account!("Share Link User")
      expires_at = DateTime.add(DateTime.utc_now(), 3600, :second)

      attrs = %{
        account_id: account.id,
        kind: :location,
        expires_at: expires_at,
        capabilities: %{"targets" => %{"irc" => %{"mode" => "geo_link"}}}
      }

      assert {:ok, link} = ShareLinks.create_link(attrs)
      assert link.expires_at |> DateTime.truncate(:second) == DateTime.truncate(expires_at, :second)
      assert link.capabilities["targets"]["irc"]["mode"] == "geo_link"
    end
  end

  describe "create_bridge_link/3" do
    test "uses bridge account ownership and defaults" do
      account = insert_account!("Bridge Owner")
      bridge_account = insert_bridge_account!(account, "telegram")

      attrs = %{payload: %{"download" => %{"url" => "https://files/pic"}}}

      assert {:ok, link} = ShareLinks.create_bridge_link(bridge_account, :image, attrs)
      assert link.account_id == account.id
      assert link.bridge_account_id == bridge_account.id
      assert link.usage == :bridge
      assert link.view_count == 0
    end
  end

  describe "fetch_active/2" do
    test "increments view count and enforces limits" do
      account = insert_account!("Limit User")

      {:ok, link} =
        ShareLinks.create_link(%{
          account_id: account.id,
          kind: :file,
          max_views: 1,
          payload: %{"download" => %{"url" => "https://files/doc.pdf"}}
        })

      assert {:ok, loaded} = ShareLinks.fetch_active(link.token)
      assert loaded.view_count == 1
      assert {:error, :view_limit_reached} = ShareLinks.fetch_active(link.token)
    end

    test "rejects expired links" do
      account = insert_account!("Expiry User")

      {:ok, link} = ShareLinks.create_link(%{account_id: account.id, kind: :invite})

      link
      |> Changeset.change(expires_at: DateTime.add(DateTime.utc_now(), -60, :second))
      |> Repo.update!()

      assert {:error, :expired} = ShareLinks.fetch_active(link.token)
    end
  end

  defp insert_account!(name) do
    %Account{}
    |> Account.changeset(%{display_name: name})
    |> Messngr.Repo.insert!()
  end

  defp insert_bridge_account!(account, service) do
    %BridgeAccount{}
    |> BridgeAccount.changeset(%{account_id: account.id, service: service, external_id: "ext-#{service}"})
    |> Messngr.Repo.insert!()
  end
end

