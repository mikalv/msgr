defmodule Messngr.Noise.KeyLoaderTest do
  use ExUnit.Case, async: false

  import Mox

  alias Messngr.Noise.KeyLoader

  @moduletag :noise

  setup :set_mox_global
  setup :verify_on_exit!

  setup do
    original_manager = Application.get_env(:msgr, :secrets_manager)

    on_exit(fn ->
      System.delete_env("NOISE_STATIC_KEY")
      Application.put_env(:msgr, :secrets_manager, original_manager)
    end)

    :ok
  end

  test "loads private key from environment variable" do
    key = :crypto.strong_rand_bytes(32)
    System.put_env("NOISE_STATIC_KEY", Base.encode64(key))

    assert {:ok, ^key} = KeyLoader.load()
  end

  test "falls back to configured default" do
    key = :crypto.strong_rand_bytes(32)

    assert {:ok, ^key} =
             KeyLoader.load(env_var: "MISSING_NOISE_KEY", default: Base.encode64(key))
  end

  test "derives public key and fingerprint deterministically" do
    {:ok, _type, private_key, public_key} = :enoise_keypair.new(:dh25519)

    assert KeyLoader.public_key(private_key) == public_key

    assert KeyLoader.fingerprint(private_key) ==
             private_key
             |> KeyLoader.public_key()
             |> then(&:crypto.hash(:blake2b, 32, &1))
             |> Base.encode16(case: :lower)
  end

  test "loads key via secrets manager" do
    key = :crypto.strong_rand_bytes(32)

    Application.put_env(:msgr, :secrets_manager, Messngr.SecretsManagerMock)

    expect(Messngr.SecretsManagerMock, :fetch, fn "arn:aws:secretsmanager:123", _opts ->
      {:ok, %{"SecretString" => Jason.encode!(%{"private" => Base.encode64(key)})}}
    end)

    assert {:ok, ^key} =
             KeyLoader.load(
               env_var: "NOISE_STATIC_KEY",
               secret_id: "arn:aws:secretsmanager:123",
               secret_field: "private"
             )
  end

  test "raises when invalid key length is supplied" do
    System.put_env("NOISE_STATIC_KEY", Base.encode64(<<0, 1, 2>>))

    assert {:error, {:invalid_length, {:env, "NOISE_STATIC_KEY"}, 3}} = KeyLoader.load()
  end
end
