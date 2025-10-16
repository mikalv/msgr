defmodule Messngr.Accounts.KeyStoreTest do
  use Messngr.DataCase

  alias Messngr.Accounts
  alias Messngr.Accounts.{KeyStore, ProfileKey, ProfileBackupCode}

  describe "upsert_key/2" do
    setup do
      {:ok, account} = Accounts.create_account(%{"display_name" => "Key User"})
      profile = List.first(account.profiles)
      {:ok, profile: profile}
    end

    test "creates new key and fingerprints public key", %{profile: profile} do
      {:ok, key} =
        KeyStore.upsert_key(profile, %{
          purpose: :messaging,
          public_key: "PUBKEY123",
          encrypted_payload: <<1, 2, 3>>
        })

      assert key.profile_id == profile.id
      assert key.fingerprint == KeyStore.fingerprint("PUBKEY123")
      assert key.client_snapshot_version == 1

      fetched = Repo.get(ProfileKey, key.id)
      assert fetched.encryption["cipher"] == "aes-256-gcm"
    end

    test "replaces existing key and bumps version", %{profile: profile} do
      {:ok, original} =
        KeyStore.upsert_key(profile, %{purpose: :messaging, public_key: "PUBKEY"})

      {:ok, rotated} =
        KeyStore.upsert_key(profile, %{purpose: :messaging, public_key: "NEWKEY"})

      assert rotated.id == original.id
      assert rotated.client_snapshot_version == original.client_snapshot_version + 1
      assert rotated.fingerprint == KeyStore.fingerprint("NEWKEY")
    end
  end

  describe "backup codes" do
    setup do
      {:ok, account} = Accounts.create_account(%{"display_name" => "Recovery"})
      profile = List.first(account.profiles)
      {:ok, profile: profile}
    end

    test "generate_backup_codes/2 replaces existing codes", %{profile: profile} do
      {:ok, codes} = KeyStore.generate_backup_codes(profile, quantity: 4)

      assert length(codes) == 4
      assert Enum.all?(codes, &String.contains?(&1, "-"))

      stored = Repo.all(from code in ProfileBackupCode, where: code.profile_id == ^profile.id)
      assert length(stored) == 4

      {:ok, replacement} = KeyStore.generate_backup_codes(profile, quantity: 2)
      assert length(replacement) == 2

      assert Repo.aggregate(ProfileBackupCode, :count, :id) == 2
    end

    test "redeem_backup_code/2 marks record as used", %{profile: profile} do
      {:ok, [code | _]} = KeyStore.generate_backup_codes(profile, quantity: 1)

      assert :ok = KeyStore.redeem_backup_code(profile, code)
      assert {:error, :invalid_code} = KeyStore.redeem_backup_code(profile, code)

      used = Repo.one!(ProfileBackupCode |> where([c], c.profile_id == ^profile.id))
      assert not is_nil(used.used_at)
    end
  end
end
