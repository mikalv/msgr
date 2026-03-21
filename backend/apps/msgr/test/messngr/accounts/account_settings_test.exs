defmodule Messngr.Accounts.AccountSettingsTest do
  use Messngr.DataCase

  alias Messngr.Accounts

  setup do
    {:ok, account} =
      Accounts.create_account(%{
        "display_name" => "Settings Tester",
        "email" => "settings-#{Ecto.UUID.generate()}@example.com"
      })

    {:ok, account: account}
  end

  describe "get_settings/1" do
    test "creates default settings if none exist", %{account: account} do
      {:ok, settings} = Accounts.get_settings(account.id)

      assert settings.account_id == account.id
      assert settings.notify_desktop == true
      assert settings.notify_mobile == true
      assert settings.notify_about == "everything"
      assert settings.show_online_status == true
      assert settings.locale == "en"
      assert settings.time_24h == true
    end

    test "returns existing settings on second call", %{account: account} do
      {:ok, settings1} = Accounts.get_settings(account.id)
      {:ok, settings2} = Accounts.get_settings(account.id)

      assert settings1.account_id == settings2.account_id
    end
  end

  describe "update_settings/2" do
    test "updates notification settings", %{account: account} do
      {:ok, _} = Accounts.get_settings(account.id)

      {:ok, updated} =
        Accounts.update_settings(account.id, %{
          notify_desktop: false,
          notify_mobile: false,
          notify_about: "mentions"
        })

      assert updated.notify_desktop == false
      assert updated.notify_mobile == false
      assert updated.notify_about == "mentions"
    end

    test "creates settings if none exist on update", %{account: account} do
      {:ok, settings} =
        Accounts.update_settings(account.id, %{
          locale: "nb",
          time_24h: true
        })

      assert settings.locale == "nb"
      assert settings.time_24h == true
    end

    test "validates notify_about values", %{account: account} do
      {:ok, _} = Accounts.get_settings(account.id)

      assert {:error, changeset} =
               Accounts.update_settings(account.id, %{notify_about: "invalid_value"})

      assert %{notify_about: [_]} = errors_on(changeset)
    end

    test "accepts all valid notify_about values", %{account: account} do
      for value <- ~w(everything mentions dms_only nothing) do
        {:ok, settings} = Accounts.update_settings(account.id, %{notify_about: value})
        assert settings.notify_about == value
      end
    end

    test "updates privacy settings", %{account: account} do
      {:ok, updated} =
        Accounts.update_settings(account.id, %{
          show_online_status: false,
          show_read_receipts: false,
          show_typing_indicators: false
        })

      assert updated.show_online_status == false
      assert updated.show_read_receipts == false
      assert updated.show_typing_indicators == false
    end

    test "updates status fields", %{account: account} do
      expires = DateTime.utc_now() |> DateTime.add(3600) |> DateTime.truncate(:second)

      {:ok, updated} =
        Accounts.update_settings(account.id, %{
          status_text: "In a meeting",
          status_emoji: ":calendar:",
          status_expires_at: expires
        })

      assert updated.status_text == "In a meeting"
      assert updated.status_emoji == ":calendar:"
      assert updated.status_expires_at == expires
    end

    test "updates DND settings", %{account: account} do
      {:ok, updated} =
        Accounts.update_settings(account.id, %{
          dnd_enabled: true,
          dnd_start: ~T[22:00:00],
          dnd_end: ~T[07:00:00]
        })

      assert updated.dnd_enabled == true
      assert updated.dnd_start == ~T[22:00:00]
      assert updated.dnd_end == ~T[07:00:00]
    end
  end
end
