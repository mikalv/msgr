defmodule Messngr.Noise.DevHandshakeTest do
  use ExUnit.Case, async: false

  alias Messngr.Noise.DevHandshake
  alias Messngr.Noise.KeyLoader
  alias Messngr.Transport.Noise.{Registry, Session}

  setup do
    original_noise = Application.get_env(:msgr, :noise, [])
    original_registry = Application.get_env(:msgr, :noise_session_registry, [])

    on_exit(fn ->
      Application.put_env(:msgr, :noise, original_noise)
      Application.put_env(:msgr, :noise_session_registry, original_registry)

      if pid = Process.whereis(Registry) do
        Process.exit(pid, :normal)
      end
    end)

    private_key = :crypto.strong_rand_bytes(32)
    public_key = KeyLoader.public_key(private_key)
    fingerprint = KeyLoader.fingerprint(private_key)

    noise_config = [
      enabled: true,
      private_key: private_key,
      public_key: public_key,
      fingerprint: fingerprint,
      protocol: KeyLoader.protocol(),
      prologue: KeyLoader.prologue()
    ]

    Application.put_env(:msgr, :noise, noise_config)
    Application.put_env(:msgr, :noise_session_registry, [ttl: 200])

    {:ok,
     %{
       private_key: private_key,
       public_key: public_key,
       fingerprint: fingerprint
     }}
  end

  test "generate/1 persists session and exposes server metadata", %{public_key: public_key, fingerprint: fingerprint} do
    assert {:ok, payload} = DevHandshake.generate(ttl_ms: 200)

    assert %Session{} = payload.session
    assert is_binary(payload.signature)
    assert is_binary(payload.device_key)
    assert is_binary(payload.device_private_key)
    assert DateTime.compare(payload.expires_at, DateTime.utc_now()) == :gt

    session_id = Session.id(payload.session)
    assert {:ok, ^payload.session} = Registry.fetch(session_id)

    expected_public_key = Base.encode64(public_key)

    assert %{
             protocol: KeyLoader.protocol(),
             prologue: KeyLoader.prologue(),
             fingerprint: ^fingerprint,
             public_key: ^expected_public_key
           } = payload.server
  end

  test "generate/1 returns error when transport disabled" do
    Application.put_env(:msgr, :noise, [enabled: false])

    assert {:error, :noise_transport_disabled} = DevHandshake.generate()
  end

  test "generate/1 returns error when key material missing" do
    Application.put_env(:msgr, :noise, [enabled: true, private_key: nil, public_key: nil])

    assert {:error, :noise_private_key_missing} = DevHandshake.generate()
  end
end
