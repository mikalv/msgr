defmodule Messngr.Accounts.DeviceKeyTest do
  use ExUnit.Case, async: true

  alias Messngr.Accounts.DeviceKey

  describe "normalize/1" do
    test "accepts url-safe base64 without padding" do
      key = Base.url_encode64(:crypto.strong_rand_bytes(32), padding: false)
      assert {:ok, ^key, raw} = DeviceKey.normalize(key)
      assert byte_size(raw) == 32
    end

    test "strips padding from base64 input" do
      padded = Base.url_encode64(:crypto.strong_rand_bytes(32))
      assert {:ok, normalized, raw} = DeviceKey.normalize(padded)
      refute String.contains?(normalized, "=")
      assert Base.url_decode64!(normalized, padding: false) == raw
    end

    test "decodes hex strings" do
      hex = Base.encode16(:crypto.strong_rand_bytes(32), case: :lower)
      assert {:ok, normalized, raw} = DeviceKey.normalize(hex)
      assert Base.url_decode64!(normalized, padding: false) == raw
    end

    test "rejects short keys" do
      assert {:error, :invalid_length} = DeviceKey.normalize("abcd")
    end
  end

  describe "fingerprint/1" do
    test "returns lowercase hex sha256 hash" do
      raw = :crypto.strong_rand_bytes(32)
      assert fingerprint = DeviceKey.fingerprint(raw)
      assert String.length(fingerprint) == 64
      assert fingerprint == String.downcase(fingerprint)
    end
  end
end
